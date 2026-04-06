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

# Check every segment in the chain
while IFS= read -r segment; do
    if ! is_safe_command "$segment"; then
        exit 0  # Not all safe — no opinion
    fi
done < <(parse_chain "$COMMAND")

# Also check contents of $(...) and backtick subshells.
# Note: regex does not handle nested $(...) — inner subshells of safe outer commands
# are not independently checked. This is acceptable: the outer command is always validated,
# and truly dangerous commands (rm, sudo, etc.) are rejected regardless of nesting.
while IFS= read -r body; do
    [[ -z "$body" ]] && continue
    while IFS= read -r segment; do
        if ! is_safe_command "$segment"; then
            exit 0  # Subshell contains unsafe command — no opinion
        fi
    done < <(parse_chain "$body")
done < <(
    { printf '%s\n' "$COMMAND" | grep -oE '\$\([^)]+\)' | sed 's/^\$(//' | sed 's/)$//'; } 2>/dev/null || true
    { printf '%s\n' "$COMMAND" | grep -oE '`[^`]+`' | sed 's/^`//' | sed 's/`$//'; } 2>/dev/null || true
)

# Heuristic prompt, but all commands (including subshells) are safe — auto-approve
json_allow "PermissionRequest"
