function __clade_sops_encrypt -a file pattern --description 'Encrypt secret-looking values of a settings.json in place with sops'
    # Prints the env names it encrypted. Status 0: encrypted, 2: nothing to encrypt, 1: failed.
    __clade_need sops; or return 1
    set -l names (jq -r --arg p $pattern '(.env // {}) | keys[] | select(test($p; "i"))' $file)
    if test $status -ne 0
        __clade_err "could not parse settings.json to find its secrets; nothing was exported"
        return 1
    end
    set -q names[1]; or return 2

    # sops takes recipients from its own config: SOPS_PGP_FP, SOPS_AGE_RECIPIENTS, SOPS_KMS_ARN,
    # a .sops.yaml, or flags in $clade_sops_args (e.g. --pgp FINGERPRINT).
    if not sops encrypt --input-type json --output-type json --encrypted-regex "(?i)($pattern)" \
            $clade_sops_args $file >$file.sops
        rm -f $file.sops
        __clade_err "sops could not encrypt settings.json (are recipients configured? see 'clade help export'); nothing was exported"
        return 1
    end

    # Never ship a plaintext secret: every secret-looking env value must now be sops ciphertext.
    set -l leaked (jq -r --arg p $pattern \
        '(.env // {}) | to_entries[] | select(.key | test($p; "i")) | select(.value | tostring | startswith("ENC[") | not) | .key' $file.sops)
    if test $status -ne 0; or set -q leaked[1]; or not jq -e 'has("sops")' $file.sops >/dev/null
        rm -f $file.sops
        __clade_err "sops left secret values unencrypted ("(string join ', ' $leaked)"); nothing was exported"
        return 1
    end
    mv $file.sops $file
    printf '%s\n' $names
end
