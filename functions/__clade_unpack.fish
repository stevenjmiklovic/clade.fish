function __clade_unpack --description 'Overlay a clade archive onto a profile directory'
    argparse trusted -- $argv; or return
    set -l archive $argv[1]
    set -l dest $argv[2]
    __clade_verify $archive; or return

    set -l tmp (__clade_mktemp); or return
    if not tar -xzf $archive -C $tmp
        rm -rf $tmp
        __clade_err "could not extract $archive"
        return 1
    end

    # Links in an archive from elsewhere could point anywhere; only our own snapshots may keep them.
    if not set -q _flag_trusted
        set -l odd (find $tmp ! -type f ! -type d)
        if set -q odd[1]
            rm -rf $tmp
            __clade_err "refusing $archive: it contains links or special files: "(string join ', ' (string replace -- $tmp/ '' $odd[1..5]))
            return 1
        end
    end

    # Decrypt before rewriting paths: sops's integrity check covers the plain values too.
    if test -f $tmp/settings.json; and jq -e 'has("sops")' $tmp/settings.json >/dev/null 2>&1
        if not __clade_need sops
            rm -rf $tmp
            return 1
        end
        if not sops decrypt --input-type json --output-type json $tmp/settings.json >$tmp/settings.plain
            rm -rf $tmp
            __clade_err "could not decrypt settings.json in $archive with sops; you need one of the keys it was encrypted to. Nothing was written."
            return 1
        end
        mv $tmp/settings.plain $tmp/settings.json
    end

    set -l source (jq -r '.source // empty' $tmp/clade.json)
    set -l home (jq -r '.home // empty' $tmp/clade.json)
    rm $tmp/clade.json
    if test -f $tmp/settings.json -a -n "$source"; and test "$source" != "$dest"
        __clade_rewrite_paths $tmp/settings.json $source $dest $home
    end

    set -l items $tmp/*
    if set -q items[1]
        tar -C $tmp -cf - (path basename -- $items) | tar -C $dest -xf -
        if test "$pipestatus" != "0 0"
            rm -rf $tmp
            __clade_err "could not write into "(__clade_tilde $dest)
            return 1
        end
    end
    rm -rf $tmp
end

# Point references to the source profile at the destination, in absolute, ~/ and $HOME/ forms.
function __clade_rewrite_paths -a file from to from_home
    set -l pairs $from $to
    if test -n "$from_home"; and string match -q -- "$from_home/*" $from; and string match -q -- "$HOME/*" $to
        set -l rel_from (string sub -s (math (string length -- $from_home) + 2) -- $from)
        set -l rel_to (string sub -s (math (string length -- $HOME) + 2) -- $to)
        set -a pairs "~/$rel_from" "~/$rel_to" "\$HOME/$rel_from" "\$HOME/$rel_to"
    end
    set -l text (string collect <$file)
    for i in (seq 1 2 (count $pairs))
        # Match whole path components only, so ~/.claude never rewrites ~/.claude.json.
        set -l pattern (string escape --style=regex -- $pairs[$i])'(?=[/"\'\s]|$)'
        set -l replacement (string replace -a -- '$' '$$' $pairs[(math $i + 1)])
        set text (string replace -ra -- $pattern $replacement $text | string collect)
    end
    printf '%s\n' $text >$file
end
