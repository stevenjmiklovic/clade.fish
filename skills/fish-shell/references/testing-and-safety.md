# Isolated verification for stateful fish tools

A normal `fish -c` can load the user's configuration. Reassigning a persistent preference in that process can change later shells. Establish isolation before the test fish process starts.

## Adapt an existing runner first

For clade.fish, use `fish tests/run.fish`: the repository runner supplies a temporary home, fish configuration, data directory, and GPG home, and removes relevant inherited variables. Read the runner before trusting it, because this contract can change.

For another repository, create a temporary directory owned by the test and launch a child fish process with:

- `HOME` pointing at a disposable home;
- `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and, if relevant, `XDG_CACHE_HOME` pointing inside the sandbox;
- `GNUPGHOME` set to an isolated private directory if GPG is exercised;
- package-specific profile/default/data variables removed or deliberately set;
- isolated recipient/key configuration for encryption tests;
- an explicit repository root passed to the test harness.

Redirecting HOME does not isolate every service: keychains, SSH agents, cloud SDKs, and network endpoints may still be real. Stub those dependencies or use supported test configurations when they are relevant. `fish --no-config` skips startup configuration, but it is not a substitute for isolating persistent storage.

Keep these environment assignments in the child process invocation. Do not change the user's session variables or real universal-variable store to create the sandbox. Source only the repository functions needed by the test. Disable interactive startup side effects where appropriate.

Use private permissions for secret fixtures. Cleanup only a nonempty temporary path the test created, preserve the original result, and clean up sandbox-specific agents if the test starts them. Do not place cleanup commands in startup hooks.

## Select checks by risk

| Change | Meaningful verification |
| --- | --- |
| Pure helper | Expected output/status, empty input, and boundary values |
| CLI flags | Help without arguments, invalid flags, missing values, exclusive flags, leading-dash data |
| Wrapper | An argv-recording stub confirms spaces, empty arguments, and downstream flags survive |
| Shell switching | Current-shell environment changes; inherited environment and persistent default remain distinct |
| Autoload/plugin | A fresh isolated shell loads the function, completion, and config without manual sourcing |
| Restore/merge | Backup failure aborts; failure preserves original state; additive restore keeps newer files |
| Export | Existing destination refused; only allowed data exported; documented secret fields redacted |
| Import | Traversal, absolute paths, links, special entries, and invalid metadata rejected before target writes |
| Encryption | Round-trip with disposable keys; missing key/tool failure does not create plaintext output |
| Docs | Syntax/content matches current help; links and examples resolve; responsive layout works |

For no-mutation guarantees, compare a before/after inventory and contents of the intended destination. Merely checking a nonzero exit status does not prove files were left intact. For secrets, test with synthetic sentinel values rather than live tokens.

## Compatibility checks

See [fish invocation options](https://fishshell.com/docs/current/cmds/fish.html) and [fish_indent](https://fishshell.com/docs/current/cmds/fish_indent.html) for syntax/format checks. Apply them to the changed files.

A project's test runner may require normal config loading to test `conf.d` or autoloading. Do not add `--no-config` blindly and hide the behavior under test.

Test the minimum supported fish version in CI or a genuinely installed older interpreter. Reading newer documentation or passing `fish --no-execute` on fish 4.9.3 cannot establish fish 3.6 compatibility. Record the actual `fish --version` used, rather than claiming the draft target was tested. Inspect GNU/BSD utility differences when the tool supports both Linux and macOS.

## Shared-workspace completion

Check `git status` before staging. Stage explicit task files, inspect the staged diff, and preserve work already committed by another chat. Do not claim publication from a local commit: verify the remote deployment when publication is authorized and performed.
