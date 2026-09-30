# Bash-to-fish conversion key

Use the official [Fish for Bash users](https://fishshell.com/docs/current/fish_for_bash_users.html) guide as the primary conversion reference. It covers substitutions, defaults, globs, quoting, special variables, heredocs, tests, arithmetic, process substitution, and prompts. Check the page's version against the target interpreter.

## Pocket key

| Bash intent | Fish starting point | Check before translating |
| --- | --- | --- |
| Set a local value | `set -l name value` | Block versus function scope; see [set](https://fishshell.com/docs/current/cmds/set.html). |
| Forward `"$@"` or `"${args[@]}"` | `$argv` or `$args` | Preserve separate and empty arguments; don't quote the whole list. |
| Read `$?` / `PIPESTATUS` | `$status` / `$pipestatus` | Capture before cleanup changes the result. |
| Capture command output | `(cmd)` or `$(cmd)` | Check output splitting; no backtick substitution. |
| Handle `${NAME:-fallback}` | Explicit scalar empty/unset check | `set -q` alone only checks existence. |
| Parse flags | `argparse` | Separate wrapper flags from downstream arguments. |
| Use heredocs or `set -euo pipefail` | Redesign the input/error handling | No mechanical equivalent; fish `set -e` erases a variable. |

For other constructs, consult the conversion guide rather than guessing replacements. Use [string](https://fishshell.com/docs/current/cmds/string.html) for parameter manipulation, [math](https://fishshell.com/docs/current/cmds/math.html) for arithmetic, and [psub](https://fishshell.com/docs/current/cmds/psub.html) when a consumer needs a filename instead of stdin.

## Agent translation process

1. Identify which behaviors are intentional: scope, argument boundaries, defaults, expansion, statuses, subprocesses, and cleanup.
2. Read the matching official section and translate the behavior. Keep the source shell explicit when Bash-specific code remains.
3. Preserve data as arguments. Do not replace structured forwarding with an interpolated command string.
4. Compare argv, stdout/stderr, statuses, environment, and file changes. Include empty/spaced arguments and a failing subprocess. Use a disposable environment for persistent state.

Check Bash integer versus fish math behavior, one-based list indexes, unset versus empty values, unmatched globs, and subshell assumptions when relevant. Prefer a small helper in an appropriate language over a fragile mechanical rewrite. Translating untrusted source does not authorize executing it.
