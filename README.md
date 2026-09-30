# clade.fish

[![Test](https://github.com/stevenjmiklovic/clade.fish/actions/workflows/test.yml/badge.svg)](https://github.com/stevenjmiklovic/clade.fish/actions/workflows/test.yml)
[![Release](https://img.shields.io/github/v/release/stevenjmiklovic/clade.fish)](https://github.com/stevenjmiklovic/clade.fish/releases/latest)
[![fish 3.6+](https://img.shields.io/badge/fish-3.6%2B-4AAE46?logo=fishshell&logoColor=white)](https://fishshell.com)
[![Oh My Fish](https://img.shields.io/badge/Oh%20My%20Fish-package-blue)](#install)
[![License: MIT](https://img.shields.io/github/license/stevenjmiklovic/clade.fish)](LICENSE)

Switch, snapshot and share [Claude Code](https://claude.com/claude-code) profiles from the [fish shell](https://fishshell.com).

A *profile* is a Claude Code config directory: `~/.claude`, or any `~/.<name>claude` directory next to it. Each profile has its own settings, `CLAUDE.md`, skills, agents, plugins, history and login. `clade` switches between them by managing [`CLAUDE_CONFIG_DIR`](https://code.claude.com/docs/en/settings). It can also version a profile's config with snapshots and move it between profiles and machines as an archive.

```console
$ clade
* claude       ~/.claude
  notclaude    ~/.notclaude       default, 3 snapshots
$ clade use not
Claude profile: notclaude
$ clade snapshot -m "before trying new hooks"
Saved snapshot 20260930T185201Z of notclaude.
```

## Contents

- [Install](#install)
- [Quick start](#quick-start)
- [Commands](#commands)
- [Profiles](#profiles)
- [Snapshots](#snapshots)
- [Export and import](#export-and-import)
- [Encryption](#encryption)
- [Safety](#safety)
- [Configuration](#configuration)
- [Prompt integration](#prompt-integration)
- [Uninstall](#uninstall)
- [Development](#development)

## Install

Requires fish 3.6 or newer (tested on 3.6, 3.7 and 4), `jq` (for snapshots, export and import), and `tar`. [Encryption](#encryption) is optional and needs GnuPG (for snapshots) or [sops](https://github.com/getsops/sops) 3.9 or newer (for exports).

With [Oh My Fish](https://github.com/oh-my-fish/oh-my-fish):

```fish
omf install https://github.com/stevenjmiklovic/clade.fish
omf update clade.fish                          # later, to upgrade
```

OMF names a package installed from a URL after its repository, so the package is called `clade.fish` and the command is `clade`. OMF loads new packages in new shells, so open one (or run `exec fish`) after installing.

With [Fisher](https://github.com/jorgebucaran/fisher):

```fish
fisher install stevenjmiklovic/clade.fish
```

By hand, link or copy the files into your fish config:

```fish
for f in functions/*.fish completions/*.fish conf.d/*.fish
    ln -s $PWD/$f ~/.config/fish/$f
end
```

## Quick start

```fish
clade new work --from claude      # new profile ~/.workclaude with your current config
clade use work                    # this shell now runs claude with the work profile
claude                            # log in once; the login is kept per profile
clade use -u work                 # make it the default for new shells
clade run claude -p "hello"       # one-off run with another profile
clade help                        # everything else
```

## Commands

Every command has built-in help: `clade help COMMAND` or `clade COMMAND -h`.

| Command | What it does |
| --- | --- |
| `clade list [-s]` | List profiles. `*` marks the one active in this shell. `-s` prints bare names. |
| `clade use [-u] NAME` | Switch this shell to `NAME`. `-u` also makes it the default for new shells. |
| `clade current` | Print the active profile. |
| `clade path [NAME]` | Print a profile's directory, e.g. `cd (clade path work)`. |
| `clade default [NAME]` | Show or set the profile new shells start with. |
| `clade run NAME [ARGS...]` | Run `claude` once with `NAME` without switching. Arguments go to `claude`. |
| `clade new NAME [--from SRC]` | Create `~/.NAMEclaude`, optionally copying `SRC`'s config. |
| `clade snapshot [NAME] [-m MSG]` | Save a snapshot of `NAME`'s config. |
| `clade history [NAME]` | List snapshots, newest first. |
| `clade diff [NAME] [SNAP]` | Diff a snapshot against the current config. |
| `clade restore NAME [SNAP]` | Roll back to a snapshot. The current state is snapshotted first. |
| `clade encryption [on KEY... \| off]` | Show or set GPG encryption of snapshots. |
| `clade export [NAME] [-o FILE] [--sops \| --include-secrets]` | Write `NAME`'s config to a `.clade.tar.gz` archive. `--sops` encrypts its secrets. |
| `clade import FILE [NAME] [--merge]` | Create a profile from an archive, or merge into one. |
| `clade help [COMMAND]` | Show help. |
| `clade version` | Show the version. |

`NAME` defaults to the active profile wherever it is optional. `SNAP` is a number from `clade history` (1 = newest, the default) or a snapshot ID such as `20260930T185201Z`.

## Profiles

- `clade` finds profiles by looking for directories in your home that match `~/.*claude`. `~/.claude-server-commander` and similar are ignored.
- Names are matched loosely. `clade use not` finds `~/.notclaude`, and `clade new work` creates `~/.workclaude`. A path containing `/` also works: `clade use ./sandbox/testclaude`.
- **The stock profile, `claude`, is special.** Selecting it *unsets* `CLAUDE_CONFIG_DIR` rather than pointing it at `~/.claude`, so Claude Code keeps using `~/.claude.json` and your existing login. Pointing the variable at `~/.claude` explicitly would make Claude Code treat it as a new, logged-out profile.
- `clade use` changes the current shell and the programs it starts. It does not affect a `claude` session that is already running.
- `clade use -u` or `clade default` stores the default in the universal variable `clade_default`, which applies to every new shell. A shell that inherits `CLAUDE_CONFIG_DIR` from its parent keeps it, so `clade use work; fish` stays in `work`.

## Snapshots

A snapshot is a timestamped archive of a profile's **portable config** (see below), stored in `~/.local/share/clade/snapshots/<profile>/`.

```fish
clade snapshot work -m "before plugin cleanup"
clade history work
#   1  20260930T185201Z      12K  gpg  before plugin cleanup
#   2  20260928T091512Z      11K
clade diff work               # what changed since snapshot 1?
clade restore work 2          # go back to snapshot 2
clade restore work 1          # changed your mind: snapshot 1 is now the state from before the restore
```

- A restore takes a snapshot of the current state first, so you can always undo it.
- A restore puts back every file in the snapshot and leaves files created since then in place. It lists those files and never deletes them.
- Snapshots keep secrets, so they are **not** redacted. They are written with `600` permissions in a `700` directory, and they can be [encrypted with GPG](#encrypted-snapshots-gpg).
- `clade` never deletes snapshots. They are ordinary files, so prune them by hand when you want to.
- `clade diff` exits 0 when nothing changed and 1 when something did, like `diff`, so it works in scripts.

## Export and import

```fish
clade export work -o work.clade.tar.gz     # on one machine
clade import work.clade.tar.gz work        # on another
```

**Portable config**, which is what snapshots, exports and `new --from` include:

| Included | Never included |
| --- | --- |
| `settings.json`, `CLAUDE.md`, `keybindings.json` | `.claude.json`, credentials, logins |
| `agents/`, `commands/`, `skills/`, `output-styles/` | `history.jsonl`, `projects/`, `sessions/`, `todos/` |
| `hooks/`, `rules/` | caches, logs, `file-history/`, `shell-snapshots/` |
| anything listed in `$clade_include` | `plugins/` (see below) |

**Plugins:** Plugin registries in `plugins/` store absolute paths into a plugin cache that can be hundreds of megabytes, so they aren't exported. The list of enabled plugins and extra marketplaces lives in `settings.json` (`enabledPlugins`, `extraKnownMarketplaces`), so that part travels. If plugins don't appear after an import, run `/plugin` in Claude Code.

**Secrets:** When exporting, `env` values in `settings.json` are replaced with `<redacted by clade>` if their names contain `KEY`, `TOKEN`, `SECRET`, `PASSW`, `CREDENTIAL` or `BEARER`. The archive records which values were redacted, and `clade import` lists them so you can fill them in. Use `--include-secrets` to keep them. If `settings.json` can't be parsed, the export stops instead of risking a leak. Secrets hidden elsewhere, such as inside a hook command, aren't detected, so check before sharing.

**Paths:** When a profile is imported or copied under a new name, `settings.json` references to the old profile directory are rewritten to the new one. This covers absolute, `~/` and `$HOME/` forms, on whole path components only, so `~/.claude.json` is never touched. Exports follow symlinks, so an archive is self-contained.

**Archive format:** A gzipped tar containing the config files plus `clade.json`:

```json
{ "format": 1, "clade": "0.1.0", "profile": "workclaude", "source": "/Users/you/.workclaude",
  "home": "/Users/you", "created": "2026-09-30T18:52:01Z", "label": "", "redacted": ["MY_API_KEY"] }
```

## Encryption

clade encrypts the two places secrets end up. Each uses the tool that fits it best:

- **Snapshots use GPG.** A snapshot is a whole archive that only you need to read back, so it's encrypted as one file to your own key.
- **Exports use sops.** An export's secrets are a few values in `settings.json`. sops encrypts just those values, leaves the rest readable, and can encrypt to anyone's key: PGP, age, AWS KMS, GCP KMS, Azure Key Vault or Vault.

### Encrypted snapshots (GPG)

```fish
clade encryption on you@example.com     # or a key ID or fingerprint
clade encryption                        # status: keys, private-key check, snapshot counts
clade encryption off
```

Once enabled, every new snapshot of every profile is saved as `…tar.gz.gpg`, including the automatic ones taken before `restore` and `import --merge`. Next to each one is a small `…tar.gz.gpg.json` file holding only the label, date and key fingerprints, so `clade history` never needs your passphrase. `clade diff` and `clade restore` decrypt into a private temporary directory and remove it afterwards. If you use pinentry in a terminal, set `GPG_TTY`: `set -gx GPG_TTY (tty)`.

**The main risk is losing the key, because then the snapshots can't be recovered.** clade guards against that at every step:

- **Enabling checks the key.** `encryption on` refuses a key unless its **private** key is in your keyring. It resolves the key to one exact fingerprint (an ambiguous name is refused), and a test encrypt-and-decrypt must succeed, which proves gpg-agent and any passphrase work.
- **Enabling explains backup.** It prints the `gpg --export-secret-keys` command for backing up the key. Keep the backup somewhere other than this machine.
- **Every snapshot is checked.** Each encrypted snapshot is decrypted and compared byte for byte with the original before it's kept. If that fails, nothing is saved.
- **A missing key stops everything safely.** New snapshots are refused, so `restore` and `import --merge` stop before changing anything. Restoring an encrypted snapshot decrypts it first, so a missing key also stops before anything changes. `clade encryption` reports the missing key.
- **Existing snapshots stay as they are.** They're never re-encrypted or deleted. `clade encryption` counts any left unencrypted, so you can remove them yourself.
- **Startup never decrypts.** Shell startup and completions never call GPG, so there are no passphrase prompts where no one can answer.

### Encrypted exports (sops)

```fish
set -U clade_sops_args --pgp (gpg --with-colons --list-keys you@example.com | string match -r '^fpr:.*' | head -n1 | string split -f10 :)
clade export work --sops -o work.clade.tar.gz
clade import work.clade.tar.gz work        # decrypts with sops; needs a key it was encrypted to
```

`--sops` replaces redaction. Values whose names look secret (see `clade_secret_pattern`) are encrypted as `ENC[…]`, and everything else stays readable, so a reviewer can still see what an archive contains. sops finds recipients in its own configuration:

- the `SOPS_PGP_FP`, `SOPS_AGE_RECIPIENTS` or `SOPS_KMS_ARN` environment variables;
- a `.sops.yaml` in the current directory or above;
- or flags in `clade_sops_args`, such as `--pgp FPR`, `--age RECIPIENT`, `--kms ARN` or `--config FILE`.

Several recipients work too, so one archive can be opened by you and a teammate.

**How the risks are handled:**

- **No plaintext secrets.** After encrypting, clade checks that every secret-looking value is sops ciphertext. If one isn't, or if sops fails or has no recipients, nothing is written.
- **Older versions fail safely.** sops exports use archive format `2`, which clade 0.2 and earlier refuse as unsupported. They can't silently import encrypted placeholders.
- **Imports are atomic.** They decrypt in a temporary directory before touching the profile. Without a suitable key, nothing is written and no profile is created. Decryption happens *before* paths are rewritten, because sops's integrity check covers the whole file.
- **Plain when nothing is secret.** If a profile has no secret-looking values, the export stays plain (format `1`), so any recipient can import it.

## Safety

`clade` is built to be non-destructive:

- **It never deletes a profile.** There is no `rm` command; to remove a profile, delete its directory yourself.
- **It never overwrites a profile without a snapshot.** `restore` and `import --merge` snapshot the target first, and they abort if the snapshot fails.
- **It only adds and replaces files.** A restore or merge never deletes files in the profile.
- **It never overwrites files.** `new` and `import` refuse existing profiles, and `export` refuses existing files. Archives are built in a temporary directory and moved into place.
- **It checks imports before writing anything.** It rejects archives with absolute paths, `..`, symlinks, special files, or anything outside the portable config list.
- **It leaves machine state alone.** History, sessions, projects and credentials are never read into archives or written over.
- **Encryption can't lock you out.** Snapshot encryption only accepts keys you can decrypt with, checks every encrypted snapshot, and stops before changing anything if the key goes missing. sops exports are checked for leftover plaintext before they're written. See [Encryption](#encryption).
- **Uninstalling keeps your data.** It removes only the `clade_default` variable, never profiles or snapshots.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `clade_default` | unset (`claude`) | Profile new shells start with. Set with `clade default`. |
| `clade_data_dir` | `$XDG_DATA_HOME/clade` or `~/.local/share/clade` | Where snapshots are stored. |
| `clade_include` | none | Extra paths inside a profile to treat as portable config, e.g. `set -U clade_include statusline.sh`. |
| `clade_secret_pattern` | `KEY\|TOKEN\|SECRET\|PASSW\|CREDENTIAL\|BEARER` | Case-insensitive regex for env names that exports redact, or encrypt with `--sops`. |
| `clade_gpg_recipients` | unset | GPG fingerprints that new snapshots are encrypted to. Set with `clade encryption on`. |
| `clade_sops_args` | none | Extra `sops encrypt` flags for `export --sops`, e.g. `--pgp FPR` or `--age RECIPIENT`. |

## Prompt integration

With [starship](https://starship.rs):

```toml
[env_var.CLAUDE_CONFIG_DIR]
format = "[✻ $env_value]($style) "
style = "yellow"
```

With a fish prompt, use `clade current`, or check `set -q CLAUDE_CONFIG_DIR` to show the profile only when it's not the stock one.

## Uninstall

```fish
omf remove clade.fish                      # or: fisher remove stevenjmiklovic/clade.fish
```

Profiles in `~/.*claude` and snapshots in `~/.local/share/clade` are left untouched.

## Development

```fish
fish tests/run.fish                        # the test suite runs in a throwaway HOME
fish_indent --check **/*.fish              # formatting
```

`tests/run.fish` sets `HOME`, `XDG_CONFIG_HOME` and `XDG_DATA_HOME` to a temporary directory, so the suite never touches your real profiles, snapshots or universal variables. The malicious-archive tests need `python3` and are skipped without it.

The [Test workflow](.github/workflows/test.yml) runs on every push to `main` and every pull request. It checks formatting and syntax, checks that the current version has a changelog entry, and runs the suite on fish 3.6 (built from source, the minimum supported version), fish 3.7 and fish 4 on Ubuntu, and fish 4 on macOS.

### Releasing

Versions follow [Semantic Versioning](https://semver.org). The archive format has its own `format` number, and newer releases are meant to keep importing archives made by older ones.

1. As you work, add notes under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md).
2. Run the **Release** workflow from the Actions tab (or `gh workflow run release.yml -f version=minor`). Choose `patch`, `minor`, `major` or an exact `X.Y.Z`, and tick **dry run** to preview the release first.
3. The workflow runs the full test matrix. It then bumps `__clade_version`, moves the Unreleased notes under the new version, commits `Release vX.Y.Z` to `main`, tags `vX.Y.Z` and publishes a GitHub release with those notes. OMF users get the new version with `omf update clade.fish`.

The same bump runs locally without GitHub: `fish tools/release.fish minor --dry-run`.

## License

[MIT](LICENSE)
