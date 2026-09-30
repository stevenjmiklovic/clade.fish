# Oh My Fish uninstall hook (Fisher uses the clade_uninstall event in conf.d). Profiles and snapshots are never removed.
set -qU clade_default; and set -eU clade_default
