# Run through tests/run.fish, which provides an isolated HOME.
if not set -q CLADE_SANDBOX
    echo "run the suite with: fish tests/run.fish" >&2
    exit 2
end

set -p fish_function_path $CLADE_ROOT/functions
set -p fish_complete_path $CLADE_ROOT/completions
set -g H $HOME
set -g S $CLADE_SANDBOX
set -g passed 0
set -g failed 0

# Record the status of the command just before it.
function ok -a desc
    if test $status -eq 0
        set passed (math $passed + 1)
    else
        set failed (math $failed + 1)
        echo "not ok - $desc" >&2
    end
end

function quiet
    $argv >/dev/null 2>&1
end

function file_mode -a file
    stat -c %a $file 2>/dev/null; or stat -f %Lp $file
end

function json -a file filter
    jq -r $filter $file
end

function newest -a key
    path basename (__clade_snapshots $key)[1]
end

# Fixtures: the stock profile and a "work" profile with a secret, a skill and machine state.
mkdir -m 700 $H/.claude $H/.workclaude $H/.claude-server-commander
echo '{"theme":"dark"}' >$H/.claude/settings.json
echo '{"theme":"dark","env":{"MY_API_KEY":"sk-123","AWS_REGION":"us-east-1"},"statusLine":{"command":"~/.workclaude/status.sh"},"other":"~/.workclaude.json"}' >$H/.workclaude/settings.json
mkdir -p $H/.workclaude/skills/demo
echo demo >$H/.workclaude/skills/demo/SKILL.md
echo history >$H/.workclaude/history.jsonl
echo '#!/bin/sh
echo "dir=$CLAUDE_CONFIG_DIR args=$*"' >$S/bin/claude
chmod +x $S/bin/claude
set -gx PATH $S/bin $PATH
set -g in_new_shell fish -c "set -p fish_function_path $CLADE_ROOT/functions; source $CLADE_ROOT/conf.d/clade.fish; clade current"

# --- help and version
string match -q 'clade 0.*' (clade --version)
ok version
string match -q 'Usage: clade COMMAND*' (clade help)[1]
ok "top-level help"
test (clade use -h)[1] = 'Usage: clade use [-u | --universal] NAME'
ok "command help via -h"
test (clade help restore)[1] = 'Usage: clade restore NAME [SNAP]'
ok "command help via help CMD"
set -l missing_help
for c in list use current path default run new snapshot history diff restore export import help version
    __clade_help $c | string match -q 'Usage: clade*'; or set -a missing_help $c
end
not set -q missing_help[1]
ok "every command has help"
not quiet clade help bogus
ok "help for an unknown command fails"
not quiet clade bogus
ok "unknown command fails"
string match -q 'Usage: clade use*' (clade use 2>&1)
ok "a missing argument prints usage"

# --- listing and switching
test "$(clade list -s)" = "claude
workclaude"
ok "list -s finds profiles and ignores other ~/.claude* dirs"
string match -q '\* claude*' (clade list)[1]
ok "list marks the active profile"
quiet clade use work; and test "$CLAUDE_CONFIG_DIR" = $H/.workclaude
ok "use sets CLAUDE_CONFIG_DIR"
test (clade current) = workclaude
ok "current names the profile"
test (clade path) = $H/.workclaude
ok "path prints its directory"
not quiet clade use nope; and test "$CLAUDE_CONFIG_DIR" = $H/.workclaude
ok "use of an unknown profile fails and changes nothing"
quiet clade use claude; and not set -q CLAUDE_CONFIG_DIR
ok "use claude unsets the variable"
test (clade run work -p hi) = "dir=$H/.workclaude args=-p hi"
ok "run passes the profile and arguments"
test (env CLAUDE_CONFIG_DIR=x fish -c "set -p fish_function_path $CLADE_ROOT/functions; clade run claude") = "dir= args="
ok "run claude runs without the variable"

# --- defaults across shells
quiet clade use -u work; and test (clade default) = workclaude
ok "use -u sets the default"
test (env -u CLAUDE_CONFIG_DIR $in_new_shell) = workclaude
ok "new shells start in the default"
test (env CLAUDE_CONFIG_DIR=$H/.claude $in_new_shell) = claude
ok "an inherited profile wins over the default"
clade default claude; and not set -q clade_default
ok "default claude clears it"
test (env -u CLAUDE_CONFIG_DIR $in_new_shell) = claude
ok "new shells then use the stock profile"
quiet clade use claude

# --- new
quiet clade new personal; and test (file_mode $H/.personalclaude) = 700
ok "new creates a private profile"
not quiet clade new personal
ok "new refuses an existing profile"
not quiet clade new ../evil
ok "new rejects unsafe names"
quiet clade new copy --from work
and test (json $H/.copyclaude/settings.json .env.MY_API_KEY) = sk-123
and test -f $H/.copyclaude/skills/demo/SKILL.md
ok "new --from copies config"
test ! -e $H/.copyclaude/history.jsonl
ok "new --from leaves machine state behind"
test (json $H/.copyclaude/settings.json .statusLine.command) = "~/.copyclaude/status.sh"
ok "new --from rewrites profile paths"
test (json $H/.copyclaude/settings.json .other) = "~/.workclaude.json"
ok "path rewriting respects component boundaries"

# --- snapshots
quiet clade snapshot work -m "First try"
ok "snapshot saves one"
quiet clade snapshot work -m "First try"; and test (count (__clade_snapshots workclaude)) -eq 2
ok "two snapshots in the same second get distinct files"
string match -q '*1  2*First try' (clade history work)
ok "history lists snapshots with labels"
test (file_mode (__clade_snapshots workclaude)[1]) = 600
ok "snapshots are private"
string match -q '*sk-123*' (tar -xzOf (__clade_snapshots workclaude)[1] settings.json)
ok "snapshots keep secrets"
quiet clade diff work
ok "diff reports no change"
echo '{"theme":"light"}' >$H/.workclaude/settings.json
echo new >$H/.workclaude/CLAUDE.md
set -l out (clade diff work)
test $status -eq 1; and string match -q '*"theme":"light"*' -- $out
ok "diff shows changes and exits 1"
quiet clade restore work 1; and test (json $H/.workclaude/settings.json .theme) = dark
ok "restore rolls back"
test -f $H/.workclaude/CLAUDE.md
ok "restore keeps files newer than the snapshot"
string match -q '*before-restoring*' (newest workclaude)
ok "restore snapshots first"
quiet clade restore work 1; and test (json $H/.workclaude/settings.json .theme) = light
ok "restore can be undone"
quiet clade restore work (__clade_snap_id (__clade_snapshots workclaude)[-1])
and test (json $H/.workclaude/settings.json .theme) = dark
ok "restore by ID"
not quiet clade restore work 99
ok "restore of an unknown snapshot fails"
test (cat $H/.workclaude/history.jsonl) = history
ok "restore leaves machine state alone"

# --- export
cd $S
quiet clade export work -o $S/work.tar.gz; and test (file_mode $S/work.tar.gz) = 600
ok "export writes a private archive"
test (tar -xzOf $S/work.tar.gz settings.json | jq -r .env.MY_API_KEY) = "<redacted by clade>"
ok "export redacts secrets"
test (tar -xzOf $S/work.tar.gz settings.json | jq -r .env.AWS_REGION) = us-east-1
ok "export keeps other env values"
test (tar -xzOf $S/work.tar.gz clade.json | jq -r '.redacted[0]') = MY_API_KEY
ok "export records what it redacted"
not string match -q '*history.jsonl*' (tar -tzf $S/work.tar.gz)
ok "export leaves machine state out"
set -l before (shasum $S/work.tar.gz)
not quiet clade export work -o $S/work.tar.gz; and test (shasum $S/work.tar.gz) = "$before"
ok "export never overwrites"
quiet clade export work -o $S/secret.tar.gz --include-secrets
and test (tar -xzOf $S/secret.tar.gz settings.json | jq -r .env.MY_API_KEY) = sk-123
ok "export --include-secrets keeps them"
quiet clade export work; and test -f $S/workclaude-(date +%Y%m%d).clade.tar.gz
ok "export picks a default file name"
echo 'not json' >$H/.personalclaude/settings.json
not quiet clade export personal -o $S/bad.tar.gz; and test ! -e $S/bad.tar.gz
ok "export refuses settings it cannot redact, writing nothing"

# --- import
quiet clade import $S/work.tar.gz team
ok "import creates a new profile"
test (json $H/.teamclaude/settings.json .statusLine.command) = "~/.teamclaude/status.sh"
ok "import rewrites profile paths"
test -f $H/.teamclaude/skills/demo/SKILL.md
ok "import brings skills"
string match -q '*MY_API_KEY*' (clade import $S/work.tar.gz team2)
ok "import names the redacted values"
not quiet clade import $S/work.tar.gz team
ok "import refuses an existing profile"
echo '{"theme":"mine"}' >$H/.teamclaude/settings.json
quiet clade import $S/work.tar.gz team --merge
and string match -q '*before-importing*' (newest teamclaude)
and test (json $H/.teamclaude/settings.json .theme) = dark
ok "import --merge snapshots first"
rm -rf $H/.workclaude
quiet clade import $S/work.tar.gz; and test -f $H/.workclaude/settings.json
ok "import without a name uses the archive's"
not quiet clade import $S/missing.tar.gz
ok "import of a missing file fails"

if type -q python3
    python3 -c '
import io, json, sys, tarfile
def build(path, entries, link=None):
    with tarfile.open(path, "w:gz") as t:
        for name, data in [("clade.json", json.dumps({"format": 1}).encode())] + entries:
            info = tarfile.TarInfo(name); info.size = len(data); t.addfile(info, io.BytesIO(data))
        if link:
            info = tarfile.TarInfo(link[0]); info.type = tarfile.SYMTYPE; info.linkname = link[1]; t.addfile(info)
d = sys.argv[1]
build(d + "/traversal.tar.gz", [("skills/../../evil", b"x")])
build(d + "/absolute.tar.gz", [("/tmp/clade-evil", b"x")])
build(d + "/state.tar.gz", [("history.jsonl", b"x")])
build(d + "/link.tar.gz", [], link=("skills", "/etc"))
' $S
    for evil in traversal absolute state link
        not quiet clade import $S/$evil.tar.gz evil$evil
        ok "import rejects a $evil archive"
        test ! -e $H/.evil{$evil}claude
        ok "a rejected $evil archive creates nothing"
    end
    test ! -e $H/evil -a ! -e /tmp/clade-evil
    ok "nothing escapes the profile"
else
    echo "skip - malicious archive tests need python3" >&2
end

# --- completions
contains restore (complete -C 'clade ' | string split -f1 \t)
ok "completes commands"
contains teamclaude (complete -C 'clade use ' | string split -f1 \t)
ok "completes profile names"
contains 1 (complete -C 'clade restore work ' | string split -f1 \t)
ok "completes snapshots"

echo "$passed passed, $failed failed"
test $failed -eq 0
