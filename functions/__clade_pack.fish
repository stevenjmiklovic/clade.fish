function __clade_pack --description 'Archive the portable config of a Claude profile'
    argparse redact dereference 'label=' -- $argv; or return
    set -l dir $argv[1]
    set -l out $argv[2]
    __clade_need jq; or return
    if test -e $out
        __clade_err "$out already exists"
        return 1
    end

    set -l files
    for rel in (__clade_portable)
        if test -e $dir/$rel; or test -L $dir/$rel
            set -a files $rel
        end
    end

    set -l tmp (__clade_mktemp); or return
    set -l tar_flags -c
    set -q _flag_dereference; and set tar_flags -ch
    if set -q files[1]
        tar -C $dir $tar_flags -f - $files | tar -C $tmp -xf -
        if test "$pipestatus" != "0 0"
            rm -rf $tmp
            __clade_err "could not read the config in "(__clade_tilde $dir)
            return 1
        end
    end

    set -l redacted
    if set -q _flag_redact; and test -f $tmp/settings.json
        set -l pattern 'KEY|TOKEN|SECRET|PASSW|CREDENTIAL|BEARER'
        test -n "$clade_secret_pattern"; and set pattern $clade_secret_pattern
        set redacted (jq -r --arg p $pattern '(.env // {}) | keys[] | select(test($p; "i"))' $tmp/settings.json)
        and if set -q redacted[1]
            jq --arg p $pattern '.env |= with_entries(if (.key | test($p; "i")) then .value = "<redacted by clade>" else . end)' \
                $tmp/settings.json >$tmp/settings.redacted
            and mv $tmp/settings.redacted $tmp/settings.json
        end
        # Never write an export whose secrets could not be checked.
        if test $status -ne 0
            rm -rf $tmp
            __clade_err "could not parse settings.json to redact secrets; nothing was exported"
            return 1
        end
        if set -q redacted[1]
            __clade_err "note: redacted secret-looking env values: "(string join ', ' $redacted)" (--include-secrets keeps them)"
        end
    end

    jq -n --arg clade $__clade_version --arg profile (__clade_key $dir) --arg source $dir --arg home $HOME \
        --arg created (date -u +%Y-%m-%dT%H:%M:%SZ) --arg label "$_flag_label" \
        '{format: 1, clade: $clade, profile: $profile, source: $source, home: $home,
          created: $created, label: $label, redacted: $ARGS.positional}' \
        --args $redacted >$tmp/clade.json

    # Build inside the temp dir, then move into place without replacing anything.
    tar -C $tmp -czf $tmp/archive.tar.gz clade.json $files
    and chmod 600 $tmp/archive.tar.gz
    and mv -n $tmp/archive.tar.gz $out
    if test $status -ne 0; or test -e $tmp/archive.tar.gz
        rm -rf $tmp
        __clade_err "could not write $out"
        return 1
    end
    rm -rf $tmp
end
