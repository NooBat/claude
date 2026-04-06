#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BLOCK_REASON=""

# check_rm_destructive() — block rm -rf / (root filesystem wipe)
check_rm_destructive() {
    local args="${EFFECTIVE_CMD#rm}"
    # Must have recursive+force flags (-rf, -fr, -r -f, etc.)
    if [[ ! "$args" =~ (^|[[:space:]])-[a-z]*r[a-z]*([[:space:]]|$) ]]; then
        return 1
    fi
    # Check if targeting root /
    local -a tokens
    read -r -a tokens <<< "$args"
    for tok in "${tokens[@]:-}"; do
        [[ "$tok" == -* ]] && continue
        if [[ "$tok" == "/" ]]; then
            BLOCK_REASON="BLOCKED: 'rm -rf /' would wipe the entire filesystem"
            return 0
        fi
    done
    return 1
}

# check_git_destructive() — block hard resets, forced cleans, forced checkouts
check_git_destructive() {
    parse_git_subcommand "$EFFECTIVE_CMD" > /dev/null

    case "$GIT_SUBCMD" in
        reset)
            if [[ "$GIT_SUBCMD_ARGS" =~ (^|[[:space:]])--hard([[:space:]]|$) ]]; then
                BLOCK_REASON="BLOCKED: 'git reset --hard' discards all uncommitted changes permanently — use 'git stash' to save changes first, or 'git reset --soft' to keep them staged"
                return 0
            fi
            return 1
            ;;
        clean)
            # Block if flags contain -f combined with -d or -x
            # Flags can be combined (-fd, -fdx) or separate (-f -d)
            local -a clean_tokens
            read -r -a clean_tokens <<< "$GIT_SUBCMD_ARGS"
            local has_f=0 has_dx=0
            for tok in "${clean_tokens[@]:-}"; do
                if [[ "$tok" =~ ^-[a-z]* ]]; then
                    # Check for combined flags (e.g. -fd, -fdx)
                    if [[ "$tok" == *f* && ("$tok" == *d* || "$tok" == *x*) ]]; then
                        BLOCK_REASON="BLOCKED: 'git clean -fd' permanently deletes untracked files and directories — use 'git clean -n' to preview what would be deleted first"
                        return 0
                    fi
                    # Track separate flags across tokens
                    [[ "$tok" == *f* ]] && has_f=1
                    [[ "$tok" == *d* || "$tok" == *x* ]] && has_dx=1
                fi
            done
            if (( has_f && has_dx )); then
                BLOCK_REASON="BLOCKED: 'git clean -fd' permanently deletes untracked files and directories — use 'git clean -n' to preview what would be deleted first"
                return 0
            fi
            return 1
            ;;
        checkout)
            # Block --force or standalone -f
            if [[ "$GIT_SUBCMD_ARGS" =~ (^|[[:space:]])(--force|-f)([[:space:]]|$) ]]; then
                BLOCK_REASON="BLOCKED: 'git checkout --force' discards uncommitted changes — use 'git stash' first, or 'git checkout' without --force"
                return 0
            fi
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# check_chmod_destructive() — block recursive 777 on protected paths
check_chmod_destructive() {
    local args="${EFFECTIVE_CMD#chmod}"

    # Must have -R flag
    if [[ "$args" != *-R* ]]; then
        return 1
    fi

    # Must have 777 mode
    if [[ "$args" != *777* ]]; then
        return 1
    fi

    # Must target a protected path: /, ~, /home, /etc, /usr, /var
    # Extract last token as target
    local -a tokens
    read -r -a tokens <<< "$args"
    local token_count="${#tokens[@]}"
    local target="${tokens[$((token_count - 1))]:-}"

    # tilde can't be matched unquoted in case patterns (expands to $HOME)
    if [[ "$target" == "/" || "$target" == "~" || "$target" == "/home" || \
          "$target" == "/etc" || "$target" == "/usr" || "$target" == "/var" || \
          "$target" == /home/* || "$target" == /etc/* || \
          "$target" == /usr/* || "$target" == /var/* ]]; then
        BLOCK_REASON="BLOCKED: 'chmod -R 777' on system path '$target' would make files world-writable — use specific permissions (e.g. 755) on specific subdirectories"
        return 0
    fi
    return 1
}

# check_find_destructive() — block broad -delete operations
check_find_destructive() {
    local args="${EFFECTIVE_CMD#find}"

    # Must have -delete flag
    if [[ "$args" != *-delete* ]]; then
        return 1
    fi

    # Extract the path argument: in find, paths come BEFORE the first expression flag
    # e.g., "find /tmp -name '*.log' -delete" → path is /tmp
    # e.g., "find -name '*.log' -delete" → no path (implicit ., which is broad)
    local -a tokens
    read -r -a tokens <<< "$args"

    local target=""
    for tok in "${tokens[@]:-}"; do
        # Once we hit a token starting with -, we've left the path section
        if [[ "$tok" == -* ]]; then
            break
        fi
        target="$tok"
    done

    # Broad paths: /, ~, ., or absent (empty = defaults to cwd)
    # tilde can't be matched unquoted in case patterns (expands to $HOME), use [[ ]]
    if [[ "$target" == "/" || "$target" == "~" || "$target" == "." || "$target" == "" ]]; then
        BLOCK_REASON="BLOCKED: 'find -delete' on broad path '${target:-.}' would recursively delete matching files — use a specific directory path, or run 'find' without -delete to preview first"
        return 0
    fi
    return 1
}

# is_destructive() — main entry point, routes to sub-checkers
# $1: single command segment string
is_destructive() {
    local cmd="$1"

    extract_base_cmd "$cmd" > /dev/null || return 1

    case "$BASE_CMD" in
        rm)
            check_rm_destructive
            return $?
            ;;
        git)
            check_git_destructive
            return $?
            ;;
        chmod)
            check_chmod_destructive
            return $?
            ;;
        find)
            check_find_destructive
            return $?
            ;;
        sudo)
            # Strip "sudo" and re-check the remainder
            local remainder="${EFFECTIVE_CMD#sudo}"
            remainder="${remainder#"${remainder%%[![:space:]]*}"}"  # ltrim
            if [[ -z "$remainder" ]]; then
                return 1
            fi
            is_destructive "$remainder"
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
        if is_destructive "$segment"; then
            json_deny "PreToolUse" "$BLOCK_REASON"
        fi
    done < <(parse_chain "$COMMAND")

    exit 0
fi
