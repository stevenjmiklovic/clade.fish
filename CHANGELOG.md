# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
