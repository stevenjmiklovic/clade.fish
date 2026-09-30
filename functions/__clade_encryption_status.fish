function __clade_encryption_status --description 'Describe how snapshots and exports are encrypted'
    if set -q clade_gpg_recipients[1]
        echo "Snapshots: encrypted with GPG to"
        for fingerprint in $clade_gpg_recipients
            set -l uid (gpg --batch --with-colons --list-keys -- $fingerprint 2>/dev/null | string match -r -- '^uid:.*' | string split -f10 :)[1]
            set -l state 'private key present'
            gpg --batch --list-secret-keys -- $fingerprint >/dev/null 2>&1; or set state 'PRIVATE KEY MISSING: snapshots will fail until it is restored'
            printf '  %s  %s (%s)\n' $fingerprint "$uid" $state
        end
    else
        echo "Snapshots: not encrypted (enable with: clade encryption on KEY)"
    end

    set -l plain (count (__clade_data_dir)/snapshots/*/*.tar.gz)
    set -l encrypted (count (__clade_data_dir)/snapshots/*/*.tar.gz.gpg)
    echo "Stored:    $encrypted encrypted, $plain unencrypted snapshot(s) in "(__clade_tilde (__clade_data_dir)/snapshots)
    if set -q clade_gpg_recipients[1]; and test $plain -gt 0
        echo "           clade never rewrites or deletes snapshots; remove old unencrypted ones by hand if you want."
    end
    set -l sops_note
    type -q sops; or set sops_note " (sops is not installed)"
    echo "Exports:   'clade export --sops' encrypts secret values with sops$sops_note"
end
