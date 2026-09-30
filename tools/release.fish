#!/usr/bin/env fish
# Prepare a release: bump __clade_version and move CHANGELOG.md's Unreleased notes
# under the new version. Prints the new version. Used by .github/workflows/release.yml.
#
# Usage: fish tools/release.fish (patch | minor | major | X.Y.Z) [--notes FILE] [--dry-run]
#   --notes FILE   Also write the new version's release notes to FILE
#   --dry-run      Show the result without changing any files

function fail
    echo "release: $argv" >&2
    exit 1
end

argparse 'notes=' dry-run -- $argv; or exit 2
set -q argv[1]; or fail "usage: fish tools/release.fish (patch | minor | major | X.Y.Z) [--notes FILE] [--dry-run]"

set -l root (path resolve (status dirname)/..)
set -l source_file $root/functions/clade.fish
set -l changelog $root/CHANGELOG.md
set -l repo https://github.com/stevenjmiklovic/clade.fish

set -l current (string match -rg '^set -g __clade_version (\d+\.\d+\.\d+)$' <$source_file)
test -n "$current"; or fail "could not find __clade_version in functions/clade.fish"
set -l v (string split . $current)

switch $argv[1]
    case major
        set new (math $v[1] + 1).0.0
    case minor
        set new $v[1].(math $v[2] + 1).0
    case patch
        set new $v[1].$v[2].(math $v[3] + 1)
    case '*'
        string match -qr '^\d+\.\d+\.\d+$' -- $argv[1]; or fail "'$argv[1]' is not patch, minor, major or X.Y.Z"
        set new $argv[1]
end

# The new version must be higher than the current one.
set -l n (string split . $new)
set -l higher 0
for i in 1 2 3
    if test $n[$i] -gt $v[$i]
        set higher 1
        break
    else if test $n[$i] -lt $v[$i]
        break
    end
end
test $higher = 1; or fail "$new is not higher than the current version $current"
if git -C $root rev-parse -q --verify refs/tags/v$new >/dev/null
    fail "tag v$new already exists"
end

# Split the changelog around the Unreleased section.
set -l lines (string split \n -- (string collect <$changelog))
set -l start (contains -i -- '## [Unreleased]' $lines); or fail "CHANGELOG.md has no '## [Unreleased]' heading"
set -l stop (count $lines)
for i in (seq (math $start + 1) (count $lines))
    if string match -q -- '## [*' $lines[$i]; or string match -q -- '[*]: *' $lines[$i]
        set stop (math $i - 1)
        break
    end
end
set -l notes
test $stop -gt $start; and set notes $lines[(math $start + 1)..$stop]
# Drop blank lines around the notes, keeping their inner layout.
while set -q notes[1]; and test -z (string trim -- $notes[1])
    set -e notes[1]
end
while set -q notes[1]; and test -z (string trim -- $notes[-1])
    set -e notes[-1]
end
set -q notes[1]; or fail "the Unreleased section of CHANGELOG.md is empty; describe the changes first"

set -l updated $lines[1..$start] '' "## [$new] - "(date -u +%Y-%m-%d) '' $notes ''
set -a updated $lines[(math $stop + 1)..-1]
set updated (string replace -r -- '^\[Unreleased\]: .*' "[Unreleased]: $repo/compare/v$new...HEAD" $updated)
set -l link (contains -i -- "[Unreleased]: $repo/compare/v$new...HEAD" $updated)
and set updated $updated[1..$link] "[$new]: $repo/compare/v$current...v$new" $updated[(math $link + 1)..-1]

if set -q _flag_dry_run
    echo "release: would bump $current -> $new with these notes:" >&2
    printf '%s\n' $notes >&2
else
    printf '%s\n' $updated >$changelog
    string replace -r -- '^set -g __clade_version .*' "set -g __clade_version $new" <$source_file >$source_file.tmp
    and mv $source_file.tmp $source_file
end
if set -q _flag_notes
    printf '%s\n' $notes >$_flag_notes
end
echo $new
