#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/git-check.sh"
source "$SCRIPT_DIR/project-commands.sh"

# Universal safe commands whitelist
UNIVERSAL_SAFE_COMMANDS="cat head tail less more wc grep rg egrep fgrep locate ls tree stat file which where type date uptime uname hostname whoami id printenv pwd df du free top ps lsof echo printf sort uniq diff comm cut tr tee basename dirname realpath readlink cd true false test jq yq column rev nl seq yes mkdir cp mv touch ln chmod chown export"

# Globals set by extract_base_cmd — avoids subshell so values propagate to caller.
BASE_CMD=""         # The base command name (path-stripped first word after assignments)
EFFECTIVE_CMD=""    # The full command string with leading assignments stripped

# extract_base_cmd() — extract the base command name from a command string
# Strips leading env var assignments (KEY=value, KEY="val", KEY='val'), then takes
# first word and strips path prefix. Uses char-by-char scanning to handle quoted values.
# Also sets EFFECTIVE_CMD to the full command after stripping assignments.
# $1: command string
# Prints base command name to stdout; returns 1 if no command found (pure assignment)
extract_base_cmd() {
    local cmd="$1"
    local len=${#cmd}
    local i=0

    # Skip leading whitespace
    while (( i < len )) && [[ "${cmd:$i:1}" == [[:space:]] ]]; do
        (( i++ )) || true
    done

    # Skip leading env var assignments: NAME=value (with quoted/unquoted values)
    while (( i < len )); do
        local rest="${cmd:$i}"
        if [[ "$rest" =~ ^[A-Za-z_][A-Za-z_0-9]*= ]]; then
            local match="${BASH_REMATCH[0]}"
            (( i += ${#match} )) || true

            # Skip the value
            if (( i < len )); then
                local ch="${cmd:$i:1}"
                if [[ "$ch" == '"' ]]; then
                    (( i++ )) || true
                    while (( i < len )) && [[ "${cmd:$i:1}" != '"' ]]; do
                        [[ "${cmd:$i:1}" == '\' ]] && (( i++ )) || true
                        (( i++ )) || true
                    done
                    (( i < len )) && (( i++ )) || true
                elif [[ "$ch" == "'" ]]; then
                    (( i++ )) || true
                    while (( i < len )) && [[ "${cmd:$i:1}" != "'" ]]; do
                        (( i++ )) || true
                    done
                    (( i < len )) && (( i++ )) || true
                else
                    while (( i < len )) && [[ "${cmd:$i:1}" != [[:space:]] ]]; do
                        (( i++ )) || true
                    done
                fi
            fi

            # Skip whitespace after assignment
            while (( i < len )) && [[ "${cmd:$i:1}" == [[:space:]] ]]; do
                (( i++ )) || true
            done
        else
            break
        fi
    done

    # Set EFFECTIVE_CMD to everything after assignments
    EFFECTIVE_CMD="${cmd:$i}"

    # Nothing left after assignments — pure assignment, no command
    if (( i >= len )); then
        return 1
    fi

    # Extract first word as base command
    local base=""
    while (( i < len )) && [[ "${cmd:$i:1}" != [[:space:]] ]]; do
        base+="${cmd:$i:1}"
        (( i++ )) || true
    done

    base="${base##*/}"
    BASE_CMD="$base"
    printf '%s' "$base"
}

# is_safe_command() — returns 0 if command is safe, 1 if not
# $1: single command string (no chaining — chain parsing handled upstream)
is_safe_command() {
    local cmd="$1"

    # Shell comments are safe — they do nothing
    if [[ "$cmd" == '#'* ]]; then
        return 0
    fi

    # Subshell guard: commands with $() or backticks must go through
    # heuristic-approver (PermissionRequest), not safe-approver (PreToolUse).
    # PreToolUse fires first — if we allow here, heuristic-approver never runs.
    if [[ "$cmd" == *'$('* || "$cmd" == *'`'* ]]; then
        return 1
    fi

    # Call extract_base_cmd directly (not in subshell) so globals propagate.
    # Pure assignments are not auto-approvable — they can alter the environment
    # for subsequent commands in the same shell (e.g. PATH=./malicious && git status).
    extract_base_cmd "$cmd" > /dev/null || return 1
    local base_cmd="$BASE_CMD"
    local effective="$EFFECTIVE_CMD"

    # Check universal safe commands
    if [[ " $UNIVERSAL_SAFE_COMMANDS " == *" $base_cmd "* ]]; then
        return 0
    fi

    # Delegate git commands (use effective command with assignments stripped)
    if [[ "$base_cmd" == "git" ]]; then
        is_safe_git_command "$effective"
        return $?
    fi

    # Delegate to project-specific patterns (use effective command)
    if is_safe_project_command "$effective"; then
        return 0
    fi

    return 1
}
