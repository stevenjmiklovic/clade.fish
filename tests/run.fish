#!/usr/bin/env fish
# Run the suite in a throwaway HOME, config dir and GPG home, so real profiles,
# snapshots, keys and universal variables are never touched.
set -l root (path resolve (status dirname)/..)
set -l sandbox (path resolve (mktemp -d /tmp/clade-test.XXXXXX))
mkdir -p $sandbox/home $sandbox/config $sandbox/bin
mkdir -m 700 $sandbox/gnupg

env -u CLAUDE_CONFIG_DIR -u clade_data_dir -u SOPS_PGP_FP -u SOPS_AGE_RECIPIENTS -u SOPS_KMS_ARN -u SOPS_AGE_KEY_FILE \
    HOME=$sandbox/home XDG_CONFIG_HOME=$sandbox/config XDG_DATA_HOME=$sandbox/home/.local/share \
    GNUPGHOME=$sandbox/gnupg CLADE_ROOT=$root CLADE_SANDBOX=$sandbox \
    fish $root/tests/clade.test.fish
set -l st $status
type -q gpgconf; and env GNUPGHOME=$sandbox/gnupg gpgconf --kill all 2>/dev/null
rm -rf $sandbox
exit $st
