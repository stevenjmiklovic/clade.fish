# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/stevenjmiklovic/clade.fish/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/stevenjmiklovic/clade.fish/releases/tag/v0.1.0
