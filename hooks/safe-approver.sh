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

# All segments safe — auto-approve
json_allow "PreToolUse"
