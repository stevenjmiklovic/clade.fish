function __clade_gpg_can_decrypt --description 'Check that the private key for at least one recipient is available'
    __clade_need gpg; or return
    for recipient in $argv
        gpg --batch --list-secret-keys -- $recipient >/dev/null 2>&1; and return 0
    end
    __clade_err "none of the snapshot encryption keys has its private key here ("(string join ', ' $argv)"), so a snapshot could not be restored. Import the key, or run 'clade encryption off'."
    return 1
end
