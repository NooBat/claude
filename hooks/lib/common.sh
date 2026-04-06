#!/bin/bash
set -euo pipefail

# trim() — strip leading/trailing whitespace from $1, print to stdout
trim() {
    local s="$1"
    # strip leading whitespace
    s="${s#"${s%%[![:space:]]*}"}"
    # strip trailing whitespace
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# parse_chain() — split a command string on &&, ||, |, ; respecting quotes
# Outputs one trimmed, non-empty segment per line to stdout
parse_chain() {
    local input="$1"
    local len=${#input}
    local segment=""
    local in_single_quote=0
    local in_double_quote=0
    local i=0

    while (( i < len )); do
        local ch="${input:$i:1}"

        # Handle backslash escape (outside single quotes)
        if [[ "$ch" == '\' && $in_single_quote -eq 0 ]]; then
            # consume backslash and next char literally
            segment+="$ch"
            (( i++ )) || true
            if (( i < len )); then
                segment+="${input:$i:1}"
                (( i++ )) || true
            fi
            continue
        fi

        # Toggle single quote (outside double quotes)
        if [[ "$ch" == "'" && $in_double_quote -eq 0 ]]; then
            in_single_quote=$(( 1 - in_single_quote ))
            segment+="$ch"
            (( i++ )) || true
            continue
        fi

        # Toggle double quote (outside single quotes)
        if [[ "$ch" == '"' && $in_single_quote -eq 0 ]]; then
            in_double_quote=$(( 1 - in_double_quote ))
            segment+="$ch"
            (( i++ )) || true
            continue
        fi

        # Split operators (only outside all quotes)
        if [[ $in_single_quote -eq 0 && $in_double_quote -eq 0 ]]; then
            local next_ch="${input:$((i+1)):1}"

            # Check for && or ||
            if [[ "$ch" == '&' && "$next_ch" == '&' ]]; then
                local trimmed
                trimmed="$(trim "$segment")"
                if [[ -n "$trimmed" ]]; then
                    printf '%s\n' "$trimmed"
                fi
                segment=""
                (( i += 2 )) || true
                continue
            fi

            if [[ "$ch" == '|' && "$next_ch" == '|' ]]; then
                local trimmed
                trimmed="$(trim "$segment")"
                if [[ -n "$trimmed" ]]; then
                    printf '%s\n' "$trimmed"
                fi
                segment=""
                (( i += 2 )) || true
                continue
            fi

            # Check for single | (pipe)
            if [[ "$ch" == '|' && "$next_ch" != '|' ]]; then
                local trimmed
                trimmed="$(trim "$segment")"
                if [[ -n "$trimmed" ]]; then
                    printf '%s\n' "$trimmed"
                fi
                segment=""
                (( i++ )) || true
                continue
            fi

            # Check for semicolon or newline (both are command separators in bash)
            if [[ "$ch" == ';' || "$ch" == $'\n' ]]; then
                local trimmed
                trimmed="$(trim "$segment")"
                if [[ -n "$trimmed" ]]; then
                    printf '%s\n' "$trimmed"
                fi
                segment=""
                (( i++ )) || true
                continue
            fi
        fi

        segment+="$ch"
        (( i++ )) || true
    done

    # Emit final segment
    local trimmed
    trimmed="$(trim "$segment")"
    if [[ -n "$trimmed" ]]; then
        printf '%s\n' "$trimmed"
    fi
}

# json_allow() — emit allow decision JSON to stdout
# $1: hook event name (e.g. "PreToolUse", "PermissionRequest")
json_allow() {
    local event="${1:-PreToolUse}"
    printf '{"hookSpecificOutput":{"hookEventName":"%s","permissionDecision":"allow"}}\n' "$event"
}

# json_deny() — emit deny decision JSON to stdout and exit 0
# $1: hook event name (e.g. "PreToolUse", "PermissionRequest")
# $2: reason string
json_deny() {
    local event="${1:-PreToolUse}"
    local reason="${2:-blocked}"
    # Escape backslashes and double quotes to produce valid JSON
    reason="${reason//\\/\\\\}"
    reason="${reason//\"/\\\"}"
    printf '{"hookSpecificOutput":{"hookEventName":"%s","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$event" "$reason"
    exit 0
}
