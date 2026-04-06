#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROTECTED_BRANCHES="main master"
BLOCK_REASON=""

# is_dangerous_push() — returns 0 if push is dangerous, 1 if safe
# $1: single command segment string
is_dangerous_push() {
    local cmd="$1"

    extract_base_cmd "$cmd" > /dev/null || return 1
    if [[ "$BASE_CMD" != "git" ]]; then
        return 1
    fi

    parse_git_subcommand "$EFFECTIVE_CMD" > /dev/null
    if [[ "$GIT_SUBCMD" != "push" ]]; then
        return 1
    fi

    # Tokenize the args after "push"
    local -a tokens
    read -r -a tokens <<< "$GIT_SUBCMD_ARGS"

    # Force-push check: block --force/-f but allow --force-with-lease (safer alternative)
    # Must catch combined short flags like -uf (contains f)
    local tok
    for tok in "${tokens[@]:-}"; do
        case "$tok" in
            --force)
                BLOCK_REASON="BLOCKED: 'git push --force' rewrites remote history and can destroy teammates' work — use 'git push --force-with-lease' instead, which checks that nobody else pushed first"
                return 0
                ;;
            --force-with-lease*)
                # Allow --force-with-lease (safer alternative) — skip it
                ;;
            -*)
                # Check combined short flags for 'f' (e.g., -uf, -fu, -f)
                local stripped="${tok#-}"
                if [[ "$stripped" == *f* ]]; then
                    BLOCK_REASON="BLOCKED: 'git push --force' rewrites remote history and can destroy teammates' work — use 'git push --force-with-lease' instead, which checks that nobody else pushed first"
                    return 0
                fi
                ;;
        esac
    done

    # Protected-branch check: walk tokens, skipping flags and their values
    local i=0
    local count=${#tokens[@]}
    local positional_index=0  # 0 = remote, 1+ = refspecs

    while (( i < count )); do
        tok="${tokens[$i]}"

        # Flags that consume the next token
        case "$tok" in
            --repo|--push-option|-o|--receive-pack|--exec)
                (( i++ )) || true  # skip the flag
                (( i++ )) || true  # skip its argument
                continue
                ;;
        esac

        # Any remaining flag (starts with -): skip just the flag
        if [[ "$tok" == -* ]]; then
            (( i++ )) || true
            continue
        fi

        # Positional token
        local branch=""
        if (( positional_index == 0 )); then
            positional_index=1
            # If first positional contains ':' it's a refspec (remote omitted),
            # e.g. "git push HEAD:main" or "git push :main"
            if [[ "$tok" == *:* ]]; then
                branch="${tok##*:}"
            elif [[ " $PROTECTED_BRANCHES " == *" $tok "* ]]; then
                # First positional matches a protected branch name directly
                branch="$tok"
            fi
            # Otherwise it's a remote name — no branch to check
        else
            # Refspec: check branch name
            if [[ "$tok" == *:* ]]; then
                branch="${tok##*:}"  # part after the last colon
            else
                branch="$tok"
            fi
        fi

        if [[ -n "$branch" ]] && [[ " $PROTECTED_BRANCHES " == *" $branch "* ]]; then
            BLOCK_REASON="BLOCKED: pushing to protected branch '$branch' is not allowed — push to a feature branch and create a pull request instead"
            return 0
        fi

        (( i++ )) || true
    done

    return 1
}

# Hook execution block — only runs when executed directly
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
        if is_dangerous_push "$segment"; then
            json_deny "PreToolUse" "$BLOCK_REASON"
        fi
    done < <(parse_chain "$COMMAND")

    exit 0
fi
