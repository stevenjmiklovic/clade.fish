---
name: fish-shell
description: Write, debug, review, and test fish shell tools for agentic coding. Use for .fish functions and scripts, plugins, argument parsing, completions, startup hooks, shell state, or Bash/Zsh-to-fish conversions. Also use for executing commands specifically in fish or diagnosing fish-specific quoting, scope, or compatibility failures. Do not trigger solely because a project name ends in .fish or for unrelated frontend work in a fish repository.
compatibility: Requires fish and fish_indent for executable verification. Target fish 4.9.3 for new work; preserve an existing repository's minimum version and OS support.
---

# Fish shell for coding agents

Build small fish tools with predictable arguments, intentional shell state, and verifiable behavior. Use the official documentation as the language reference; this skill supplies the working process.

## Establish the contract

Read repository instructions, relevant source, help, completions, tests, and the working tree. Identify supported fish versions, operating systems, dependencies, and package-manager conventions. Target fish 4.9.3 for new work; keep an existing older-version promise unless the user requests changing it.

Distinguish the language you are editing from the shell your execution tool runs. Invoke fish explicitly for fish code; use the executor's own syntax around that invocation. Avoid scratch names that collide with environment state: Zsh's `path`, for example, is tied to `PATH`.

Define observable success before editing: unchanged forwarded arguments, a current-shell switch, a saved default, a recoverable import, or another concrete result. Reuse existing helpers and keep changes scoped.

## Look up the relevant language behavior

- For translations, read the [Bash-to-fish conversion key](references/bash-to-fish.md) and follow its official source links.
- For syntax and expansion, consult the [fish language reference](https://fishshell.com/docs/current/language.html).
- For flags, consult [argparse](https://fishshell.com/docs/current/cmds/argparse.html).
- For state, consult [set](https://fishshell.com/docs/current/cmds/set.html) and [function](https://fishshell.com/docs/current/cmds/function.html).
- For shell integration, consult [completions](https://fishshell.com/docs/current/completions.html) and [startup configuration](https://fishshell.com/docs/current/language.html#configuration-files).

Read only the relevant sections. The `current` documentation can advance beyond 4.9.3; check its displayed version and use versioned docs or the installed interpreter's help when compatibility matters. Test the actual minimum supported version instead of inferring compatibility from current docs.

## Implement with deliberate boundaries

Keep input data as arguments, not interpolated code passed to `eval` or `fish -c`. JSON serialization is not shell escaping. Write generated multiline code to a file rather than inventing nested quoting. Preserve scalar paths, list elements, empty arguments, and downstream flags.

For wrappers, define where the wrapper's options stop; the wrapped program's `--help` belongs to that program after the boundary. Keep machine-readable stdout separate from diagnostics, and preserve the relevant exit status through logging and cleanup.

Separate temporary local state, current-shell exported state, and explicitly persistent preferences. A one-off run should use a child environment. Current-shell switching belongs in a sourced/autoloaded function, since a child cannot change its parent's environment. Define how inherited state interacts with saved defaults; unset, empty, and an explicit default path may select different credentials.

Match the existing plugin layout and lifecycle. Keep startup and completions quick and noninteractive. Avoid network access, credential prompts, decryption, or preference writes merely to open a shell or offer completions. Preserve user data during uninstall according to the package's contract.

For tools that change config or archives, validate before mutation, stage privately, refuse accidental overwrites, and preserve the promised recovery path. A failed backup, parse, redaction, or encryption step should stop the operation rather than silently weaken its guarantees. Use established encryption tools and disposable test keys when encryption is in scope. Do not add these features to tools that do not need them.

## Follow community conventions

Favor simple native constructs, responsive startup, and discoverable commands with useful completion descriptions. Use the [fish design principles](https://fishshell.com/docs/current/design.html) to guide interface choices.

- **Autoload functions by name.** Put an autoloaded function in a matching `functions/NAME.fish` file and keep initialization side effects separate. Verify loading in a fresh shell. See [function autoloading](https://fishshell.com/docs/current/language.html#autoloading-functions).
- **Keep persistent settings stable across startup.** Do not append to universal variables each time a shell starts or edit `fish_variables` directly. Set persistent preferences through fish at an explicit configuration or install step; check that repeated startup does not accumulate changes. See [universal variables](https://fishshell.com/docs/current/language.html#universal-variables).
- **Follow the selected package manager's lifecycle.** For Fisher, use `functions/`, `completions/`, and `conf.d/`; place install, update, and uninstall event handlers in `conf.d` so they are loaded when events fire. Do not assume Fisher hooks apply to other managers. See [Fisher plugin conventions](https://github.com/jorgebucaran/fisher#creating-a-plugin).
- **Treat internal completion helpers as version-sensitive.** Fish's `__fish_*` helper interfaces may change. Check any helper used against the supported versions and exercise completions in fresh shells. See [completion helper guidance](https://fishshell.com/docs/current/completions.html#useful-functions-for-writing-completions).

## Verify and deliver

Read [testing-and-safety.md](references/testing-and-safety.md) before testing stateful behavior. Reuse a repository runner that already isolates HOME, config, data, and keys; inspect it first. Never test persistent preferences against the user's real store.

Check touched fish files with `fish --no-execute` and `fish_indent --check`. Exercise relevant behavior and failure paths, including argument boundaries, missing dependencies, inherited state, overwrite refusal, and failure without partial writes. Keep tests proportional to the change.

Record the actual fish versions and platforms tested. Check GNU/BSD utility differences when supporting Linux and macOS. Keep built-in help, completions, examples, and published docs aligned with current source.

Recheck the working tree before staging explicit task files. Preserve concurrent work. Report changes and verification limits plainly; distinguish a local commit from a verified remote deployment.
