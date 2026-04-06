#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/command-check.sh"

# Guard: jq required to parse stdin
if ! command -v jq &>/dev/null; then
    exit 0
fi

INPUT=$(cat)

MESSAGE=$(printf '%s\n' "$INPUT" | jq -r '.message // empty')

if [[ -z "$MESSAGE" ]]; then
    exit 0
fi

# Only handle heuristic security prompts — pass through everything else
if ! printf '%s\n' "$MESSAGE" | grep -qiE 'command substitution|backtick|can desync quote|potential bypass|can hide characters|quoted characters|newline|ANSI.C quot'; then
    exit 0
fi

COMMAND=$(printf '%s\n' "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# is_safe_command() rejects commands containing $() or backticks (so PreToolUse
# defers them to PermissionRequest). For heuristic prompts we need to validate these:
# strip subshells from the outer command, check the outer command, then check each
# extracted subshell body independently.
strip_subshells() {
    printf '%s\n' "$1" | sed -E 's/\$\([^)]+\)/__SUBSHELL__/g' | sed -E 's/`[^`]+`/__SUBSHELL__/g'
}

extract_subshell_bodies() {
    { printf '%s\n' "$1" | grep -oE '\$\([^)]+\)' | sed 's/^\$(//' | sed 's/)$//'; } 2>/dev/null || true
    { printf '%s\n' "$1" | grep -oE '`[^`]+`' | sed 's/^`//' | sed 's/`$//'; } 2>/dev/null || true
}

# Check every segment in the chain (outer command with subshells stripped)
while IFS= read -r segment; do
    local_stripped="$(strip_subshells "$segment")"
    if ! is_safe_command "$local_stripped"; then
        exit 0  # Outer command not safe — no opinion
    fi
done < <(parse_chain "$COMMAND")

# Check contents of $(...) and backtick subshells
while IFS= read -r body; do
    [[ -z "$body" ]] && continue
    while IFS= read -r segment; do
        local_stripped="$(strip_subshells "$segment")"
        if ! is_safe_command "$local_stripped"; then
            exit 0  # Subshell contains unsafe command — no opinion
        fi
    done < <(parse_chain "$body")
done < <(extract_subshell_bodies "$COMMAND")

# Heuristic prompt, but all commands (including subshells) are safe — auto-approve
json_allow "PermissionRequest"
