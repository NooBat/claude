#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BLOCK_REASON=""

# is_git_bypass() — block git commands that bypass safety mechanisms
# $1: single command segment string
is_git_bypass() {
    local cmd="$1"

    extract_base_cmd "$cmd" > /dev/null || return 1

    case "$BASE_CMD" in
        git)
            parse_git_subcommand "$EFFECTIVE_CMD" > /dev/null

            case "$GIT_SUBCMD" in
                commit|push|merge)
                    if [[ "$GIT_SUBCMD_ARGS" =~ (^|[[:space:]])--no-verify([[:space:]]|$) ]]; then
                        BLOCK_REASON="BLOCKED: 'git $GIT_SUBCMD --no-verify' skips safety hooks — remove the --no-verify flag and fix any hook issues instead"
                        return 0
                    fi
                    return 1
                    ;;
                filter-branch)
                    BLOCK_REASON="BLOCKED: 'git filter-branch' rewrites repository history and is nearly always destructive — use 'git revert' to undo changes safely"
                    return 0
                    ;;
                filter-repo)
                    BLOCK_REASON="BLOCKED: 'git filter-repo' rewrites repository history and is nearly always destructive — use 'git revert' to undo changes safely"
                    return 0
                    ;;
                reflog)
                    # Extract first word of GIT_SUBCMD_ARGS
                    local -a reflog_tokens
                    read -r -a reflog_tokens <<< "$GIT_SUBCMD_ARGS"
                    local action="${reflog_tokens[0]:-}"

                    if [[ "$action" == "expire" || "$action" == "delete" ]]; then
                        BLOCK_REASON="BLOCKED: 'git reflog $action' destroys the safety net for recovering lost commits — the reflog should not be modified"
                        return 0
                    fi
                    return 1
                    ;;
                *)
                    return 1
                    ;;
            esac
            ;;
        sudo)
            # Strip "sudo" and re-check the remainder
            local remainder="${EFFECTIVE_CMD#sudo}"
            remainder="${remainder#"${remainder%%[![:space:]]*}"}"  # ltrim
            if [[ -z "$remainder" ]]; then
                return 1
            fi
            is_git_bypass "$remainder"
            return $?
            ;;
        *)
            return 1
            ;;
    esac
}

# Hook execution block — only runs when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
    source "$SCRIPT_DIR/lib/command-check.sh"

    if ! command -v jq &>/dev/null; then
        exit 0
    fi

    INPUT=$(cat)
    COMMAND=$(printf '%s\n' "$INPUT" | jq -r '.tool_input.command // empty')
    if [[ -z "$COMMAND" ]]; then
        exit 0
    fi

    while IFS= read -r segment; do
        if is_git_bypass "$segment"; then
            json_deny "PreToolUse" "$BLOCK_REASON"
        fi
    done < <(parse_chain "$COMMAND")

    exit 0
fi
