function __clade_snapshot_open -a file tmp --description 'Print a readable archive for a snapshot, decrypting it into TMP if needed'
    if not string match -q -- '*.gpg' $file
        echo $file
        return 0
    end
    __clade_need gpg; or return
    # TMP is a private temp dir, and callers remove it, so the plaintext never outlives the command.
    if not gpg --batch --quiet --yes --decrypt --output $tmp/snapshot.tar.gz $file
        __clade_err "could not decrypt snapshot "(__clade_snap_id $file)"; is the GPG key it was encrypted to available? (see 'clade encryption status')"
        return 1
    end
    echo $tmp/snapshot.tar.gz
end
