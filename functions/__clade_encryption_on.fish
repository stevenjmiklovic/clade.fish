function __clade_encryption_on --description 'Enable GPG encryption of snapshots after proving the keys work'
    __clade_need gpg; or return
    set -l fingerprints
    for key in $argv
        # Only accept keys whose private half is here, identified unambiguously.
        set -l listing (gpg --batch --with-colons --list-secret-keys -- $key 2>/dev/null)
        set -l primaries (string match -r -- '^sec:.*' $listing)
        if not set -q primaries[1]
            __clade_err "no private key for '$key' in your GPG keyring. Encrypting to a key you cannot decrypt with would make snapshots unrecoverable."
            return 1
        end
        if test (count $primaries) -gt 1
            __clade_err "'$key' matches "(count $primaries)" private keys; use the full fingerprint"
            return 1
        end
        set -a fingerprints (string match -r -- '^fpr:.*' $listing)[1]
    end
    set fingerprints (string split -f10 : -- $fingerprints)

    # Round trip: encrypt to every key and decrypt, so gpg-agent and any passphrase are known to work.
    set -l tmp (__clade_mktemp); or return
    echo "clade encryption check" >$tmp/plain
    set -l recipients
    for fingerprint in $fingerprints
        set -a recipients --recipient $fingerprint
    end
    if not begin
            gpg --batch --quiet --yes --trust-model always $recipients --encrypt --output $tmp/plain.gpg $tmp/plain
            and gpg --batch --quiet --yes --decrypt --output $tmp/check $tmp/plain.gpg
            and cmp -s $tmp/plain $tmp/check
        end
        rm -rf $tmp
        __clade_err "a test encrypt/decrypt with these keys failed (expired key, no encryption subkey, or passphrase not entered), so encryption was not enabled"
        return 1
    end
    rm -rf $tmp

    set -U clade_gpg_recipients $fingerprints
    echo "New snapshots of every profile will be encrypted with GPG to:"
    printf '  %s\n' $fingerprints
    echo "Existing snapshots are left as they are."
    echo
    echo "Back up the private key now. Without it, encrypted snapshots cannot be restored:"
    echo "  gpg --export-secret-keys --armor $fingerprints[1] > clade-snapshot-key.asc"
    echo "Keep that file somewhere safe and separate from this machine."
end
