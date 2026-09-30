set -l commands list ls use current path default run new snapshot history log diff restore export import help version

# True when the token being completed is the Nth positional argument after the command.
function __clade_completing_arg -a n
    set -l tokens (commandline -opc)
    set -e tokens[1..2]
    test (count (string match -v -- '-*' $tokens)) -eq (math $n - 1)
end

function __clade_complete_snapshots
    set -l tokens (commandline -opc)
    set -l dir (__clade_dir (__clade_or_current $tokens[3]) 2>/dev/null); or return
    set -l snaps (__clade_snapshots (__clade_key $dir))
    for i in (seq (count $snaps))
        printf '%s\t%s\n' $i (path basename -- $snaps[$i] | string replace -r '\.tar\.gz$' '')
    end
end

complete -c clade -f
complete -c clade -n "not __fish_seen_subcommand_from $commands" -a list -d 'List profiles'
complete -c clade -n "not __fish_seen_subcommand_from $commands" -a use -d 'Switch this shell to a profile'
complete -c clade -n "not __fish_seen_subcommand_from $commands" -a current -d 'Print the active profile'
complete -c clade -n "not __fish_seen_subcommand_from $commands" -a path -d "Print a profile's directory"
complete -c clade -n "not __fish_seen_subcommand_from $commands" -a default -d 'Profile new shells start with'
complete -c clade -n "not __fish_seen_subcommand_from $commands" -a run -d 'Run claude once with a profile'
complete -c clade -n "not __fish_seen_subcommand_from $commands" -a new -d 'Create a profile'
complete -c clade -n "not __fish_seen_subcommand_from $commands" -a snapshot -d "Snapshot a profile's config"
complete -c clade -n "not __fish_seen_subcommand_from $commands" -a history -d 'List snapshots'
complete -c clade -n "not __fish_seen_subcommand_from $commands" -a diff -d 'Compare with a snapshot'
complete -c clade -n "not __fish_seen_subcommand_from $commands" -a restore -d 'Roll back to a snapshot'
complete -c clade -n "not __fish_seen_subcommand_from $commands" -a export -d 'Write config to an archive'
complete -c clade -n "not __fish_seen_subcommand_from $commands" -a import -d 'Create a profile from an archive'
complete -c clade -n "not __fish_seen_subcommand_from $commands" -a help -d 'Show help'
complete -c clade -n "not __fish_seen_subcommand_from $commands" -s h -l help -d 'Show help'
complete -c clade -n "not __fish_seen_subcommand_from $commands" -s v -l version -d 'Show version'

complete -c clade -n "__fish_seen_subcommand_from use path default run snapshot history log diff restore export; and __clade_completing_arg 1" \
    -a '(clade list -s)'
complete -c clade -n "__fish_seen_subcommand_from diff restore; and __clade_completing_arg 2" -ka '(__clade_complete_snapshots)'
complete -c clade -n "__fish_seen_subcommand_from help; and __clade_completing_arg 1" -a "$commands"

complete -c clade -n "__fish_seen_subcommand_from list ls" -s s -l short -d 'Bare names only'
complete -c clade -n "__fish_seen_subcommand_from use" -s u -l universal -d 'Also make it the default'
complete -c clade -n "__fish_seen_subcommand_from new" -l from -xa '(clade list -s)' -d 'Copy config from profile'
complete -c clade -n "__fish_seen_subcommand_from snapshot" -s m -l message -x -d 'Snapshot label'
complete -c clade -n "__fish_seen_subcommand_from export" -s o -l output -rF -d 'Archive to write'
complete -c clade -n "__fish_seen_subcommand_from export" -l include-secrets -d 'Keep secret-looking env values'
complete -c clade -n "__fish_seen_subcommand_from import; and __clade_completing_arg 1" -F
complete -c clade -n "__fish_seen_subcommand_from import" -l merge -d 'Overlay onto an existing profile'
