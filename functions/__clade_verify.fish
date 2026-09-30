function __clade_verify -a archive --description 'Check that a file is a well-formed clade archive'
    if not test -f "$archive"
        __clade_err "no such file: $archive"
        return 1
    end
    __clade_need jq; or return

    set -l entries (tar -tzf $archive 2>/dev/null)
    if test $status -ne 0; or not set -q entries[1]
        __clade_err "$archive is not a readable .tar.gz archive"
        return 1
    end

    # Only top-level config paths are allowed; no absolute paths, no "..".
    set -l allowed clade.json (__clade_portable | string replace -r '/.*' '')
    set -l bad
    for entry in (string replace -r '^\./' '' -- $entries)
        test -n "$entry"; or continue
        if string match -qr '^/|(^|/)\.\.(/|$)' -- $entry
            or not contains -- (string split -f1 / -- $entry) $allowed
            set -a bad $entry
        end
    end
    if set -q bad[1]
        __clade_err "refusing $archive: it contains paths outside a profile's config: "(string join ', ' $bad[1..5])
        return 1
    end

    if not tar -xzOf $archive clade.json 2>/dev/null | jq -e '.format == 1' >/dev/null 2>&1
        __clade_err "$archive is not a clade archive (missing or unsupported clade.json)"
        return 1
    end
end
