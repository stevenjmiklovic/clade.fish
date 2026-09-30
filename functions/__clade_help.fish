function __clade_help -a cmd --description 'Print help for clade or one of its commands'
    switch "$cmd"
        case ''
            echo "Usage: clade COMMAND [ARGS...]

Switch, snapshot and share Claude Code profiles (CLAUDE_CONFIG_DIR).

Profiles
  list [-s]                      List profiles; * marks the one active here
  use [-u] NAME                  Switch this shell to NAME (-u: new shells too)
  current                        Print the active profile
  path [NAME]                    Print a profile's directory
  default [NAME]                 Show or set the profile new shells start with
  run NAME [ARGS...]             Run claude once with NAME, without switching
  new NAME [--from SRC]          Create a profile, optionally copying SRC's config

Versions
  snapshot [NAME] [-m MESSAGE]   Save NAME's config as a snapshot
  history [NAME]                 List snapshots, newest first
  diff [NAME] [SNAP]             Compare NAME with a snapshot
  restore NAME [SNAP]            Roll NAME back to a snapshot
  encryption [on KEY... | off]   Show or set GPG encryption of snapshots

Sharing
  export [NAME] [-o FILE] [--sops | --include-secrets]
                                 Write NAME's config to an archive
  import FILE [NAME] [--merge]   Create a profile from an archive

  help [COMMAND], -h, --help     Show help
  version, -v, --version         Show the clade version

NAME is a profile such as claude or notclaude (\"not\" works too); it defaults
to the active profile. SNAP is a number from 'clade history' (1 = newest) or
a snapshot ID. clade never deletes a profile, and snapshots before it changes
one. Run 'clade help COMMAND' for details."

        case list ls
            echo "Usage: clade list [-s | --short]

List Claude profiles: ~/.claude plus every ~/.*claude directory. The active
profile is marked with *, and notes show the default and snapshot counts.

  -s, --short   Print bare names, one per line"

        case use
            echo "Usage: clade use [-u | --universal] NAME

Switch this shell (and programs it starts) to profile NAME by setting
CLAUDE_CONFIG_DIR. Choosing claude unsets it, so the stock ~/.claude keeps its
usual ~/.claude.json and login. Running claude sessions are not affected.

  -u, --universal   Also make NAME the default for new shells"

        case current
            echo "Usage: clade current

Print the profile active in this shell: its name, or its path when it lives
outside your home directory."

        case path
            echo "Usage: clade path [NAME]

Print the directory of NAME (default: the active profile), e.g.
  cd (clade path work)"

        case default
            echo "Usage: clade default [NAME]

Without NAME, print the profile new shells start with. With NAME, make it the
default (stored in the universal variable clade_default). 'clade default
claude' goes back to the stock profile. A shell that inherits
CLAUDE_CONFIG_DIR from its parent keeps it."

        case run
            echo "Usage: clade run NAME [ARGS...]

Run claude once with profile NAME without switching this shell. Everything
after NAME is passed to claude, e.g.
  clade run work -p 'summarise this repo'"

        case new
            echo "Usage: clade new NAME [--from SRC]

Create an empty profile ~/.NAMEclaude (the claude suffix is added when
missing). Refuses to touch a directory that already exists.

  --from SRC   Copy SRC's portable config (see 'clade help export') into the
               new profile. History, sessions and logins are not copied."

        case snapshot
            echo "Usage: clade snapshot [NAME] [-m MESSAGE]

Save the portable config of NAME (default: the active profile) as a new
snapshot. Snapshots are stored unredacted, with private permissions, in
~/.local/share/clade/snapshots/NAME (or \$clade_data_dir). With
'clade encryption on KEY' they are GPG-encrypted, and each one is checked to
decrypt before it is kept. clade never deletes snapshots; remove old ones by
hand if you want to.

  -m, --message MESSAGE   Label the snapshot"

        case history log
            echo "Usage: clade history [NAME]

List snapshots of NAME (default: the active profile), newest first, with
number, ID, size, 'gpg' when encrypted, and label. Use the number or ID as
SNAP in diff and restore. Listing never needs a GPG passphrase."

        case diff
            echo "Usage: clade diff [NAME] [SNAP]

Show a unified diff from snapshot SNAP (default: 1, the newest) to NAME's
current config. Exits 0 when identical, 1 when different, 2 on error."

        case restore
            echo "Usage: clade restore NAME [SNAP]

Roll NAME back to snapshot SNAP (default: 1, the newest). The current state is
snapshotted first, so a restore can always be undone with
'clade restore NAME 1'. Files in the snapshot are put back; files created
since are left in place and listed. An encrypted snapshot is decrypted
first, so a missing key stops the restore before anything changes."

        case export
            echo "Usage: clade export [NAME] [-o FILE] [--sops | --include-secrets]

Write NAME's portable config to a .clade.tar.gz archive (default:
./NAME-YYYYMMDD.clade.tar.gz). It never overwrites an existing file.

Included: settings.json, CLAUDE.md, keybindings.json, agents/, commands/,
skills/, output-styles/, hooks/, rules/ and anything in \$clade_include.
Never included: .claude.json, credentials, history, projects, sessions,
caches and plugin caches (plugins reinstall from settings.json).

Env values in settings.json whose names look secret (KEY, TOKEN, SECRET,
PASSW, CREDENTIAL, BEARER; override with \$clade_secret_pattern) are
replaced with \"<redacted by clade>\", unless --sops encrypts them instead.

  -o, --output FILE    Where to write the archive
  --sops               Encrypt secret-looking values with sops rather than
                       redacting them. Recipients come from sops's own config
                       (SOPS_PGP_FP, SOPS_AGE_RECIPIENTS, SOPS_KMS_ARN or
                       .sops.yaml) or \$clade_sops_args, e.g.
                         set -U clade_sops_args --pgp FINGERPRINT
                       clade checks every secret was encrypted before it
                       writes the archive, which needs clade 0.3+ to import.
  --include-secrets    Keep secret-looking env values in plain text"

        case import
            echo "Usage: clade import FILE [NAME] [--merge]

Create profile NAME (default: the name stored in FILE) from an export.
Archives are checked first: only config paths are accepted, never links,
absolute paths or '..'. Paths in settings.json that pointed at the exported
profile are rewritten to the new one. Secrets encrypted with --sops are
decrypted with sops, which needs a key they were encrypted to; without one,
nothing is written.

  --merge   Import into an existing profile. It is snapshotted first, then
            the archive's files are laid over it; nothing else is removed."

        case encryption
            echo "Usage: clade encryption [status | on KEY... | off]

Show or change GPG encryption of snapshots. Exports are encrypted separately,
with 'clade export --sops'.

  status        Keys in use, whether their private keys are here, and how
                many snapshots are encrypted (the default)
  on KEY...     Encrypt new snapshots to KEY (a fingerprint, key ID or
                email). Refused unless the private key is in your keyring
                and a test encrypt/decrypt succeeds, so you can always
                restore. Back the key up: without it, encrypted snapshots
                are unrecoverable.
  off           Stop encrypting new snapshots

Existing snapshots are never re-encrypted or deleted. While encryption is on,
a snapshot fails (and so do restore and import --merge, which snapshot first)
if no private key is available. For pinentry in a terminal, set GPG_TTY:
  set -gx GPG_TTY (tty)"

        case help
            echo "Usage: clade help [COMMAND]"

        case version
            echo "Usage: clade version"

        case '*'
            __clade_err "no help for unknown command '$cmd' (see 'clade help')"
            return 1
    end
end
