# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-09-30

### Added

- A responsive documentation site with installation tabs, copyable examples, a
  searchable command reference, and automatic publishing to GitHub Pages.
- GPG encryption of snapshots: `clade encryption [status | on KEY... | off]`. Keys are accepted only
  when their private key is present and a test encrypt/decrypt succeeds. Every encrypted snapshot is
  checked to decrypt before it is kept, and labels live in an unencrypted sidecar so `history` never
  prompts.
- `clade export --sops` encrypts secret-looking values in `settings.json` with sops instead of
  redacting them, and refuses to write the archive if any secret would stay in plain text. `import`
  decrypts them, and writes nothing without a suitable key.
- Archive format 2 for sops exports, so older clade versions refuse them rather than import encrypted
  placeholders.
- The Test workflow installs GnuPG and sops and requires the encryption tests to run.

### Changed

- `restore` decrypts an encrypted snapshot before taking its safety snapshot, so a missing key changes
  nothing.
- `history` shows `gpg` for encrypted snapshots.

## [0.2.0] - 2026-09-30

### Added

- A Test workflow that lints and runs the suite on fish 3.6 (the minimum), 3.7 and 4,
  on Ubuntu and macOS.
- A manually dispatched Release workflow that bumps the version, rolls the changelog,
  tags and publishes a GitHub release (with a dry-run option), plus `tools/release.fish`.
- Status, release, license and fish-version badges in the README.

## [0.1.0] - 2026-09-30

### Added

- Profile switching: `list`, `use`, `current`, `path`, `default`, `run` and `new [--from]`.
- A default profile for new shells, stored in the universal variable `clade_default`.
- Snapshots of a profile's portable config: `snapshot`, `history`, `diff` and `restore`.
- Sharing: `export`, which redacts secret-looking env values, and `import`, which validates
  archives and rewrites profile paths.
- Built-in help for every command, and completions.
- Distribution as an Oh My Fish package (`omf install https://github.com/stevenjmiklovic/clade.fish`),
  also installable with Fisher.

[Unreleased]: https://github.com/stevenjmiklovic/clade.fish/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/stevenjmiklovic/clade.fish/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/stevenjmiklovic/clade.fish/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/stevenjmiklovic/clade.fish/releases/tag/v0.1.0
