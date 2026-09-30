set -g __clade_version 0.3.0

function clade --description 'Switch, snapshot and share Claude Code profiles'
    set -l cmd list
    if set -q argv[1]
        set cmd $argv[1]
        set -e argv[1]
    end

    switch $cmd
        case -h --help help
            __clade_help $argv
            return
        case -v --version version
            echo "clade $__clade_version"
            return
    end

    # `clade CMD -h` shows help for CMD. `run` passes everything after NAME through to claude.
    if test $cmd = run
        if contains -- "$argv[1]" -h --help
            __clade_help run
            return
        end
    else if contains -- -h $argv; or contains -- --help $argv
        __clade_help $cmd
        return
    end

    switch $cmd
        case list ls
            argparse s/short -- $argv; or return
            set -l names
            for dir in $HOME/.*claude/
                set -a names (__clade_key $dir)
            end
            if set -q _flag_short
                set -q names[1]; and printf '%s\n' $names
                return 0
            end
            set -l active (clade current)
            set -l default (clade default)
            contains -- $active $names; or set -a names $active
            set -l width (math max (string length -- $names | string join ,), 11)
            set -l on
            set -l dim
            set -l off
            if isatty stdout
                set on (set_color green)
                set dim (set_color brblack)
                set off (set_color normal)
            end
            for name in $names
                set -l dir (__clade_dir $name 2>/dev/null)
                set -l mark ' '
                set -l color
                if test $name = $active
                    set mark '*'
                    set color $on
                end
                set -l notes
                test $name = $default; and set -a notes default
                set -l n (count (__clade_snapshots (__clade_key $dir)))
                test $n -eq 1; and set -a notes '1 snapshot'
                test $n -gt 1; and set -a notes "$n snapshots"
                printf '%s %s%s%s  %s  %s%s%s\n' $mark "$color" (string pad -r -w $width -- $name) "$off" \
                    (string pad -r -w (math $width + 2) -- (__clade_tilde $dir)) "$dim" (string join ', ' $notes) "$off"
            end

        case current
            if not set -q CLAUDE_CONFIG_DIR
                echo claude
            else if test (path dirname -- $CLAUDE_CONFIG_DIR) = $HOME
                __clade_key $CLAUDE_CONFIG_DIR
            else
                echo $CLAUDE_CONFIG_DIR
            end

        case path
            __clade_dir (__clade_or_current $argv[1])

        case use
            argparse u/universal -- $argv; or return
            set -q argv[1]; or __clade_usage use; or return
            set -l dir (__clade_dir $argv[1]); or return
            if __clade_is_stock $dir
                set -e -g CLAUDE_CONFIG_DIR
            else
                set -gx CLAUDE_CONFIG_DIR $dir
            end
            if set -qU CLAUDE_CONFIG_DIR
                __clade_err "warning: a universal CLAUDE_CONFIG_DIR is also set and may shadow profiles; remove it with: set -eU CLAUDE_CONFIG_DIR"
            end
            if set -q _flag_universal
                clade default $argv[1]; or return
            end
            echo "Claude profile: "(clade current)

        case default
            if not set -q argv[1]
                set -q clade_default; and echo $clade_default; or echo claude
                return 0
            end
            set -l dir (__clade_dir $argv[1]); or return
            if __clade_is_stock $dir
                set -qU clade_default; and set -eU clade_default
            else if test (path dirname -- $dir) = $HOME
                set -U clade_default (__clade_key $dir)
            else
                set -U clade_default $dir
            end
            return 0

        case run
            set -q argv[1]; or __clade_usage run; or return
            __clade_need claude; or return
            set -l dir (__clade_dir $argv[1]); or return
            if __clade_is_stock $dir
                env -u CLAUDE_CONFIG_DIR claude $argv[2..]
            else
                env CLAUDE_CONFIG_DIR=$dir claude $argv[2..]
            end

        case new
            argparse 'from=' -- $argv; or return
            set -q argv[1]; or __clade_usage new; or return
            set -l name (__clade_normalize $argv[1]); or return
            set -l dir $HOME/.$name
            if test -e $dir
                __clade_err "~/.$name already exists"
                return 1
            end
            set -l src
            if set -q _flag_from
                set src (__clade_dir $_flag_from); or return
            end
            mkdir -m 700 $dir; or return
            if test -n "$src"
                if not __clade_copy $src $dir
                    rmdir $dir 2>/dev/null
                    return 1
                end
                echo "Created ~/.$name with the config of "(__clade_key $src)"."
            else
                echo "Created ~/.$name."
            end
            echo "Switch with 'clade use $name', then run claude to log in."

        case snapshot
            argparse 'm/message=' -- $argv; or return
            set -l dir (__clade_dir (__clade_or_current $argv[1])); or return
            set -l file (__clade_snapshot $dir "$_flag_message"); or return
            echo "Saved snapshot "(__clade_snap_id $file)" of "(__clade_key $dir)"."

        case history log
            set -l dir (__clade_dir (__clade_or_current $argv[1])); or return
            set -l key (__clade_key $dir)
            set -l snaps (__clade_snapshots $key)
            if not set -q snaps[1]
                echo "No snapshots of $key yet. Create one with: clade snapshot $key"
                return 0
            end
            __clade_need jq; or return
            for i in (seq (count $snaps))
                set -l s $snaps[$i]
                set -l lock ''
                set -l label
                if string match -q -- '*.gpg' $s
                    # Encrypted snapshots keep their label in an unencrypted sidecar, so listing never prompts.
                    set lock gpg
                    set label (jq -r '.label // ""' $s.json 2>/dev/null)
                else
                    set label (tar -xzOf $s clade.json 2>/dev/null | jq -r '.label // ""' 2>/dev/null)
                end
                set -l size (du -h $s | string split -f1 \t | string trim)
                printf '%3d  %-19s %6s  %-3s  %s\n' $i (__clade_snap_id $s) $size "$lock" "$label"
            end

        case diff
            set -l dir (__clade_dir (__clade_or_current $argv[1])); or return
            set -l snap (__clade_snapshot_ref (__clade_key $dir) $argv[2]); or return
            set -l tmp (__clade_mktemp); or return
            mkdir $tmp/snapshot $tmp/current
            if not begin
                    set -l readable (__clade_snapshot_open $snap $tmp)
                    and tar -xzf $readable -C $tmp/snapshot
                    and __clade_pack $dir $tmp/current.tar.gz
                    and tar -xzf $tmp/current.tar.gz -C $tmp/current
                end
                rm -rf $tmp
                return 2
            end
            rm -f $tmp/snapshot/clade.json $tmp/current/clade.json
            diff -ru $tmp/snapshot $tmp/current | string replace -a -- $tmp/ ''
            set -l st $pipestatus[1]
            rm -rf $tmp
            test $st -eq 0; and echo "No changes since snapshot "(__clade_snap_id $snap)"."
            return $st

        case restore
            set -q argv[1]; or __clade_usage restore; or return
            set -l dir (__clade_dir $argv[1]); or return
            set -l key (__clade_key $dir)
            set -l snap (__clade_snapshot_ref $key $argv[2]); or return
            set -l id (__clade_snap_id $snap)
            # Decrypt first: if the key is missing, nothing has been touched yet.
            set -l tmp (__clade_mktemp); or return
            set -l readable (__clade_snapshot_open $snap $tmp)
            if test $status -ne 0
                rm -rf $tmp
                __clade_err "nothing was restored"
                return 1
            end
            set -l safety (__clade_snapshot $dir "before restoring $id")
            if test $status -ne 0
                rm -rf $tmp
                __clade_err "could not snapshot the current state, so nothing was restored"
                return 1
            end
            if not __clade_unpack --trusted $readable $dir
                rm -rf $tmp
                return 1
            end
            echo "Restored $key to snapshot $id."
            echo "The previous state is snapshot "(__clade_snap_id $safety)"; undo with: clade restore $key 1"
            set -l after (__clade_entries $readable)
            set -l kept
            mkdir $tmp/safety
            set -l before (__clade_snapshot_open $safety $tmp/safety)
            and for f in (__clade_entries $before)
                contains -- $f $after; or set -a kept $f
            end
            rm -rf $tmp
            if set -q kept[1]
                echo "Kept "(count $kept)" file(s) that are newer than the snapshot (restore never deletes):"
                printf '  %s\n' $kept
            end

        case export
            argparse 'o/output=' include-secrets sops -- $argv; or return
            if set -q _flag_sops; and set -q _flag_include_secrets
                __clade_err "--sops already keeps secrets (encrypted); drop --include-secrets"
                return 1
            end
            set -l dir (__clade_dir (__clade_or_current $argv[1])); or return
            set -l key (__clade_key $dir)
            set -l out $key-(date +%Y%m%d).clade.tar.gz
            set -q _flag_output; and set out $_flag_output
            if test -e $out
                __clade_err "$out already exists; choose another file with -o"
                return 1
            end
            set -l secrets --redact
            set -q _flag_include_secrets; and set secrets
            set -q _flag_sops; and set secrets --sops
            __clade_pack --dereference $secrets $dir $out; or return
            set -l encrypted (tar -xzOf $out clade.json | jq -r '.sops[]?')
            if set -q encrypted[1]
                echo "Exported $key to $out, with "(count $encrypted)" secret value(s) encrypted by sops."
            else
                echo "Exported $key to $out."
            end

        case import
            argparse merge -- $argv; or return
            set -q argv[1]; or __clade_usage import; or return
            set -l file $argv[1]
            __clade_verify $file; or return
            set -l meta (tar -xzOf $file clade.json)
            set -l name $argv[2]
            test -n "$name"; or set name (printf '%s\n' $meta | jq -r '.profile // empty')
            set name (__clade_normalize "$name"); or return
            set -l dir $HOME/.$name
            set -l created 0
            if test -e $dir
                if not set -q _flag_merge
                    __clade_err "~/.$name already exists. Import under another name (clade import FILE NAME), or overlay it with --merge (a snapshot is taken first)."
                    return 1
                end
                set -l safety (__clade_snapshot $dir "before importing "(path basename -- $file))
                if test $status -ne 0
                    __clade_err "could not snapshot ~/.$name, so nothing was imported"
                    return 1
                end
                echo "Saved snapshot "(__clade_snap_id $safety)" of $name before merging."
            else
                mkdir -m 700 $dir; or return
                set created 1
            end
            if not __clade_unpack $file $dir
                test $created = 1; and rmdir $dir 2>/dev/null
                return 1
            end
            echo "Imported $file into ~/.$name."
            set -l decrypted (printf '%s\n' $meta | jq -r '.sops[]?')
            set -q decrypted[1]; and echo "Decrypted "(count $decrypted)" secret value(s) with sops: "(string join ', ' $decrypted)
            set -l redacted (printf '%s\n' $meta | jq -r '.redacted[]?')
            if set -q redacted[1]
                echo "These env values in settings.json were redacted on export; fill them in: "(string join ', ' $redacted)
            end
            test $created = 1; and echo "Switch with 'clade use $name', then run claude to log in."
            return 0

        case encryption
            set -l action status
            if set -q argv[1]
                set action $argv[1]
                set -e argv[1]
            end
            switch $action
                case status
                    __clade_encryption_status
                case on
                    set -q argv[1]; or __clade_usage encryption; or return
                    __clade_encryption_on $argv
                case off
                    set -qU clade_gpg_recipients; and set -eU clade_gpg_recipients
                    set -qg clade_gpg_recipients; and set -eg clade_gpg_recipients
                    echo "New snapshots will not be encrypted. Existing encrypted snapshots still need their key to be read."
                case '*'
                    __clade_usage encryption
            end

        case '*'
            __clade_err "unknown command '$cmd' (see 'clade help')"
            return 1
    end
end

function __clade_err
    echo "clade: $argv" >&2
    return 1
end

function __clade_usage -a cmd
    __clade_help $cmd | head -n1 >&2
    return 1
end

function __clade_need -a cmd
    if not type -q $cmd
        __clade_err "$cmd is required but was not found on PATH"
        return 1
    end
end

# Resolve NAME to a profile directory: ~/.NAME, then ~/.NAMEclaude, then a literal path.
function __clade_dir -a name
    if test -z "$name"
        __clade_err "missing profile name"
        return 1
    end
    for dir in $HOME/.$name $HOME/.{$name}claude
        if string match -q -- '*claude' $dir; and test -d $dir
            path normalize -- $dir
            return 0
        end
    end
    if string match -q -- '*/*' $name; and test -d $name
        string match -q -- '/*' $name; or set name $PWD/$name
        path normalize -- $name
        return 0
    end
    __clade_err "no profile '$name' (see 'clade list')"
end

# ~/.claude is the stock profile, used when CLAUDE_CONFIG_DIR is unset.
function __clade_is_stock -a dir
    test (path normalize -- $dir) = (path normalize -- $HOME/.claude)
end

# The profile name for a directory: ~/.notclaude -> notclaude.
function __clade_key -a dir
    path basename -- $dir | string replace -r '^\.' ''
end

# Validate a new profile name and give it the "claude" suffix: work -> workclaude.
function __clade_normalize -a name
    set name (string replace -r '^\.' '' -- $name)
    if not string match -qr '^[A-Za-z0-9][A-Za-z0-9_-]*$' -- $name
        __clade_err "invalid profile name '$argv[1]' (use letters, digits, - and _)"
        return 1
    end
    string match -q -- '*claude' $name; or set name {$name}claude
    echo $name
end

function __clade_or_current
    if test -n "$argv[1]"
        echo $argv[1]
    else
        clade current
    end
end

function __clade_tilde -a dir
    string replace -r -- '^'(string escape --style=regex -- $HOME) '~' $dir
end

function __clade_mktemp
    set -l base /tmp
    test -n "$TMPDIR"; and set base (string trim -r -c / -- $TMPDIR)
    mktemp -d $base/clade.XXXXXX
end

function __clade_data_dir
    if test -n "$clade_data_dir"
        echo $clade_data_dir
    else if test -n "$XDG_DATA_HOME"
        echo $XDG_DATA_HOME/clade
    else
        echo $HOME/.local/share/clade
    end
end

# Paths inside a profile that make up its configuration. Everything else (history,
# sessions, caches, credentials, plugin caches) is machine state and never leaves.
function __clade_portable
    printf '%s\n' settings.json CLAUDE.md keybindings.json agents commands skills output-styles hooks rules $clade_include
end

# Snapshot files of a profile, newest first.
function __clade_snapshots -a key
    set -l store (__clade_data_dir)/snapshots/$key
    set -l files $store/*.tar.gz $store/*.tar.gz.gpg
    set -q files[1]; and path sort -r -- $files
    return 0
end

function __clade_snap_id -a file
    path basename -- $file | string replace -r '^([0-9]{8}T[0-9]{6}Z(\.[0-9]+)?).*' '$1'
end

# Resolve a snapshot reference (history number, ID, ID prefix or file) to a file.
function __clade_snapshot_ref -a key ref
    set -l snaps (__clade_snapshots $key)
    if not set -q snaps[1]
        __clade_err "no snapshots of $key (create one with: clade snapshot $key)"
        return 1
    end
    test -n "$ref"; or set ref 1
    if string match -qr '^[0-9]+$' -- $ref
        if test $ref -ge 1 -a $ref -le (count $snaps)
            echo $snaps[$ref]
            return 0
        end
        __clade_err "$key has no snapshot #$ref (it has "(count $snaps)")"
        return 1
    end
    if test -f $ref
        path normalize -- $ref
        return 0
    end
    set -l matches
    for s in $snaps
        if test (__clade_snap_id $s) = $ref
            echo $s
            return 0
        end
        string match -q -- "$ref*" (path basename -- $s); and set -a matches $s
    end
    if test (count $matches) -eq 1
        echo $matches
        return 0
    end
    if set -q matches[1]
        __clade_err "'$ref' matches "(count $matches)" snapshots of $key; use its number from 'clade history $key'"
    else
        __clade_err "no snapshot of $key matches '$ref' (see 'clade history $key')"
    end
    return 1
end

# Files (not directories) stored in an archive, minus the manifest.
function __clade_entries -a archive
    tar -tzf $archive | string replace -r '^\./' '' | string match -rv '^$|/$|^clade\.json$'
end

function __clade_copy -a src dest
    set -l tmp (__clade_mktemp); or return
    __clade_pack --dereference $src $tmp/copy.tar.gz
    and __clade_unpack --trusted $tmp/copy.tar.gz $dest
    set -l st $status
    rm -rf $tmp
    return $st
end
