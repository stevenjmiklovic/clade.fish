# Start new shells in the default Claude profile. A CLAUDE_CONFIG_DIR inherited
# from the parent process always wins.
if set -q clade_default; and not set -q CLAUDE_CONFIG_DIR
    clade use $clade_default >/dev/null
end

# Fisher emits this before removing the plugin's files.
function _clade_uninstall --on-event clade_uninstall
    set -qU clade_default; and set -eU clade_default
    echo "clade: uninstalled. Your profiles and snapshots were left in place."
end
