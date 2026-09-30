#!/usr/bin/env fish
# Run the suite in a throwaway HOME and config dir, so real profiles, snapshots
# and universal variables are never touched.
set -l root (path resolve (status dirname)/..)
set -l sandbox (path resolve (mktemp -d /tmp/clade-test.XXXXXX))
mkdir -p $sandbox/home $sandbox/config $sandbox/bin

env -u CLAUDE_CONFIG_DIR -u clade_data_dir HOME=$sandbox/home XDG_CONFIG_HOME=$sandbox/config \
    XDG_DATA_HOME=$sandbox/home/.local/share CLADE_ROOT=$root CLADE_SANDBOX=$sandbox \
    fish $root/tests/clade.test.fish
set -l st $status
rm -rf $sandbox
exit $st
