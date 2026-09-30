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
- [Safety](#safety)
- [Configuration](#configuration)
- [Prompt integration](#prompt-integration)
- [Uninstall](#uninstall)
- [Development](#development)

## Install

Requires fish 3.6 or newer (tested on 3.6, 3.7 and 4), `jq` (for snapshots, export and import), and `tar`.

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
| `clade export [NAME] [-o FILE] [--include-secrets]` | Write `NAME`'s config to a `.clade.tar.gz` archive. |
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
#   1  20260930T185201Z      12K  before plugin cleanup
#   2  20260928T091512Z      11K
clade diff work               # what changed since snapshot 1?
clade restore work 2          # go back to snapshot 2
clade restore work 1          # changed your mind: snapshot 1 is now the state from before the restore
```

- A restore takes a snapshot of the current state first, so you can always undo it.
- A restore puts back every file in the snapshot and leaves files created since then in place. It lists those files and never deletes them.
- Snapshots keep secrets, so they are **not** redacted. They are written with `600` permissions in a `700` directory.
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

## Safety

`clade` is built to be non-destructive:

- **It never deletes a profile.** There is no `rm` command; to remove a profile, delete its directory yourself.
- **It never overwrites a profile without a snapshot.** `restore` and `import --merge` snapshot the target first, and they abort if the snapshot fails.
- **It only adds and replaces files.** A restore or merge never deletes files in the profile.
- **It never overwrites files.** `new` and `import` refuse existing profiles, and `export` refuses existing files. Archives are built in a temporary directory and moved into place.
- **It checks imports before writing anything.** It rejects archives with absolute paths, `..`, symlinks, special files, or anything outside the portable config list.
- **It leaves machine state alone.** History, sessions, projects and credentials are never read into archives or written over.
- **Uninstalling keeps your data.** It removes only the `clade_default` variable, never profiles or snapshots.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `clade_default` | unset (`claude`) | Profile new shells start with. Set with `clade default`. |
| `clade_data_dir` | `$XDG_DATA_HOME/clade` or `~/.local/share/clade` | Where snapshots are stored. |
| `clade_include` | none | Extra paths inside a profile to treat as portable config, e.g. `set -U clade_include statusline.sh`. |
| `clade_secret_pattern` | `KEY\|TOKEN\|SECRET\|PASSW\|CREDENTIAL\|BEARER` | Case-insensitive regex for env names redacted on export. |

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
