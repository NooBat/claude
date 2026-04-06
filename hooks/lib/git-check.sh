#!/bin/bash
set -euo pipefail

# Globals set by parse_git_subcommand()
# GIT_SUBCMD     — the git subcommand (e.g. "branch", "tag", "status")
# GIT_SUBCMD_ARGS — remaining tokens after the subcommand, space-joined
GIT_SUBCMD=""
GIT_SUBCMD_ARGS=""

# parse_git_subcommand() — given a full git command string, set GIT_SUBCMD and GIT_SUBCMD_ARGS.
# Strips the "git" prefix, skips non-invasive global flags (-c key=val, -C dir, etc.),
# then sets GIT_SUBCMD to the first non-flag token and GIT_SUBCMD_ARGS to everything after it.
# Also prints the subcommand to stdout for callers that need it.
parse_git_subcommand() {
    local cmd="$1"

    # Tokenize by splitting on spaces (simple split — git args don't have quoted spaces in practice here)
    local -a tokens
    read -r -a tokens <<< "$cmd"

    local i=0
    local len=${#tokens[@]}

    # Skip the "git" token itself
    if [[ "${tokens[$i]:-}" == "git" ]]; then
        (( i++ )) || true
    fi

    # Skip non-invasive global flags
    while (( i < len )); do
        local tok="${tokens[$i]}"
        case "$tok" in
            --no-pager|--no-optional-locks|-P|--paginate|--bare|--literal-pathspecs)
                (( i++ )) || true
                ;;
            -C|--work-tree|-c)
                # consumes next argument
                (( i++ )) || true
                (( i++ )) || true
                ;;
            --git-dir)
                # --git-dir value (space-separated)
                (( i++ )) || true
                (( i++ )) || true
                ;;
            --git-dir=*|--work-tree=*)
                # --git-dir=value or --work-tree=value (inline)
                (( i++ )) || true
                ;;
            *)
                break
                ;;
        esac
    done

    if (( i < len )); then
        GIT_SUBCMD="${tokens[$i]}"
        (( i++ )) || true
        if (( i < len )); then
            GIT_SUBCMD_ARGS="${tokens[*]:$i}"
        else
            GIT_SUBCMD_ARGS=""
        fi
        printf '%s' "$GIT_SUBCMD"
    else
        GIT_SUBCMD=""
        GIT_SUBCMD_ARGS=""
    fi
}

# is_safe_git_command() — returns 0 if safe, 1 if not safe
# $1: full git command string (e.g. "git -C /repo status --short")
is_safe_git_command() {
    local cmd="$1"
    GIT_SUBCMD=""
    GIT_SUBCMD_ARGS=""
    # Call directly (not in a subshell) so GIT_SUBCMD and GIT_SUBCMD_ARGS are set in this shell
    parse_git_subcommand "$cmd" > /dev/null
    local subcmd="$GIT_SUBCMD"
    local subcmd_args="$GIT_SUBCMD_ARGS"

    # Always-safe subcommands
    case "$subcmd" in
        status|diff|log|show|remote|fetch|describe|rev-parse|ls-files|ls-tree|\
        cat-file|name-rev|shortlog|blame|reflog|for-each-ref|count-objects|\
        symbolic-ref|worktree)
            return 0
            ;;
    esac

    # Subcommand-specific checks — use $subcmd_args (tokens after subcommand only, not the full command)
    case "$subcmd" in
        branch)
            # Safe only if no modify flags present in the args after "branch"
            if [[ "$subcmd_args" =~ (^|[[:space:]])(-D|-d|--delete|-m|--move|-c|--copy|-M)([[:space:]]|$) ]]; then
                return 1
            fi
            return 0
            ;;

        tag)
            # Safe with -l/--list flag
            if [[ "$subcmd_args" =~ (^|[[:space:]])(-l|--list)([[:space:]]|$) ]]; then
                return 0
            fi
            # Safe if no non-flag tokens after "tag" (bare "git tag" or "git tag --flags-only")
            local has_non_flag=0
            local -a after_tokens
            read -r -a after_tokens <<< "$subcmd_args"
            for tok in "${after_tokens[@]:-}"; do
                if [[ -n "$tok" && "$tok" != -* ]]; then
                    has_non_flag=1
                    break
                fi
            done
            if [[ $has_non_flag -eq 1 ]]; then
                return 1
            fi
            return 0
            ;;

        stash)
            # Safe only with "list" as the first argument
            if [[ "$subcmd_args" == "list" || "$subcmd_args" =~ ^list([[:space:]]|$) ]]; then
                return 0
            fi
            return 1
            ;;

        config)
            # Safe only with read-only flags in args after "config"
            if [[ "$subcmd_args" =~ (^|[[:space:]])(--get|--get-all|--get-regexp|--list|-l)([[:space:]]|$) ]]; then
                return 0
            fi
            # Handle --list or -l as the sole arg (no surrounding spaces, end-of-string)
            if [[ "$subcmd_args" == "--list" || "$subcmd_args" == "-l" || \
                  "$subcmd_args" == "--get" || "$subcmd_args" == "--get-all" || \
                  "$subcmd_args" == "--get-regexp" ]]; then
                return 0
            fi
            return 1
            ;;

        *)
            return 1
            ;;
    esac
}
