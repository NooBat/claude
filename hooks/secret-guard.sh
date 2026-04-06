#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BLOCK_REASON=""

# Overridable in tests — match .env and .env.* only (not .envrc, .environment, etc.)
env_exists_check() { compgen -G ".env" 2>/dev/null || compgen -G ".env.*" 2>/dev/null; }

# is_dangerous_add() — returns 0 if dangerous git add, 1 if safe
# $1: single command segment string
is_dangerous_add() {
    local cmd="$1"

    extract_base_cmd "$cmd" > /dev/null || return 1
    if [[ "$BASE_CMD" != "git" ]]; then
        return 1
    fi

    parse_git_subcommand "$EFFECTIVE_CMD" > /dev/null
    if [[ "$GIT_SUBCMD" != "add" ]]; then
        return 1
    fi

    # Tokenize args after "add"
    local -a tokens
    read -r -a tokens <<< "$GIT_SUBCMD_ARGS"

    local broad_add=0
    local -a positional=()

    local tok
    for tok in "${tokens[@]:-}"; do
        case "$tok" in
            -A|--all)
                broad_add=1
                ;;
            -*)
                # Other flags: -n, -v, -f, -u, -N, etc. — skip
                ;;
            *)
                positional+=("$tok")
                ;;
        esac
    done

    # Broad add check: -A/--all or sole positional is "."
    if [[ $broad_add -eq 1 ]] || \
       [[ ${#positional[@]} -eq 1 && "${positional[0]}" == "." ]]; then
        local env_output
        env_output="$(env_exists_check)"
        if [[ -n "$env_output" ]]; then
            BLOCK_REASON="BLOCKED: 'git add .' or 'git add -A' would stage .env files found in the working directory — add specific files by name instead, or add .env* to .gitignore"
            return 0
        fi
        return 1
    fi

    # Individual file check: match basename against secret patterns
    local path basename
    for path in "${positional[@]:-}"; do
        basename="${path##*/}"
        if [[ "$basename" == ".env" || "$basename" == .env.* ]]; then
            BLOCK_REASON="BLOCKED: '$path' is an environment file that likely contains secrets — add it to .gitignore instead of staging it"
            return 0
        fi
        if [[ "$basename" == *.pem || "$basename" == *.key || "$basename" == *.p12 ]]; then
            BLOCK_REASON="BLOCKED: '$path' is a cryptographic key/certificate file — these should never be committed to version control"
            return 0
        fi
        if [[ "$basename" == "id_rsa" || "$basename" == "credentials.json" ]]; then
            BLOCK_REASON="BLOCKED: '$path' is a credential file — these should never be committed to version control"
            return 0
        fi
    done

    return 1
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
        if is_dangerous_add "$segment"; then
            json_deny "PreToolUse" "$BLOCK_REASON"
        fi
    done < <(parse_chain "$COMMAND")

    exit 0
fi
