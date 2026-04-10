#!/bin/bash
set -euo pipefail

# _scan_subshells() — char-by-char parser that finds $() and backtick subshells,
# respecting quoting and nested parentheses.
# Mode "strip":   replaces each subshell with __SUBSHELL__, prints result
# Mode "extract": prints one subshell body per line (content between $( and matching ))
# $1: command string   $2: mode ("strip" or "extract")
_scan_subshells() {
    local input="$1" mode="$2"
    local len=${#input}
    local i=0
    local result=""
    local in_sq=0 in_dq=0

    while (( i < len )); do
        local ch="${input:$i:1}"

        # Backslash escape (outside single quotes)
        if [[ "$ch" == '\' && $in_sq -eq 0 ]]; then
            result+="$ch"
            (( i++ )) || true
            if (( i < len )); then
                result+="${input:$i:1}"
                (( i++ )) || true
            fi
            continue
        fi

        # Toggle single quote (outside double quotes)
        if [[ "$ch" == "'" && $in_dq -eq 0 ]]; then
            in_sq=$(( 1 - in_sq ))
            result+="$ch"
            (( i++ )) || true
            continue
        fi

        # Toggle double quote (outside single quotes)
        if [[ "$ch" == '"' && $in_sq -eq 0 ]]; then
            in_dq=$(( 1 - in_dq ))
            result+="$ch"
            (( i++ )) || true
            continue
        fi

        # Match subshells outside single quotes ($() expands inside double quotes)
        if [[ $in_sq -eq 0 ]]; then

            # $( ... ) — track nesting depth
            if [[ "$ch" == '$' && "${input:$((i+1)):1}" == '(' ]]; then
                (( i += 2 )) || true
                local depth=1 body="" sq=0 dq=0
                while (( i < len && depth > 0 )); do
                    local c="${input:$i:1}"
                    # Backslash escape inside subshell (outside single quotes)
                    if [[ "$c" == '\' && $sq -eq 0 ]]; then
                        body+="$c"
                        (( i++ )) || true
                        if (( i < len )); then
                            body+="${input:$i:1}"
                            (( i++ )) || true
                        fi
                        continue
                    fi
                    if [[ "$c" == "'" && $dq -eq 0 ]]; then
                        sq=$(( 1 - sq ))
                    elif [[ "$c" == '"' && $sq -eq 0 ]]; then
                        dq=$(( 1 - dq ))
                    elif [[ $sq -eq 0 && $dq -eq 0 ]]; then
                        if [[ "$c" == '(' ]]; then
                            (( depth++ )) || true
                        elif [[ "$c" == ')' ]]; then
                            (( depth-- )) || true
                            if (( depth == 0 )); then
                                (( i++ )) || true
                                break
                            fi
                        fi
                    fi
                    body+="$c"
                    (( i++ )) || true
                done
                if [[ "$mode" == "strip" ]]; then
                    result+="__SUBSHELL__"
                else
                    printf '%s\n' "$body"
                fi
                continue
            fi

            # Backtick subshell
            if [[ "$ch" == '`' ]]; then
                (( i++ )) || true
                local body=""
                while (( i < len )); do
                    local c="${input:$i:1}"
                    if [[ "$c" == '\' ]]; then
                        body+="$c"
                        (( i++ )) || true
                        if (( i < len )); then
                            body+="${input:$i:1}"
                            (( i++ )) || true
                        fi
                        continue
                    fi
                    if [[ "$c" == '`' ]]; then
                        (( i++ )) || true
                        break
                    fi
                    body+="$c"
                    (( i++ )) || true
                done
                if [[ "$mode" == "strip" ]]; then
                    result+="__SUBSHELL__"
                else
                    printf '%s\n' "$body"
                fi
                continue
            fi
        fi

        result+="$ch"
        (( i++ )) || true
    done

    if [[ "$mode" == "strip" ]]; then
        printf '%s\n' "$result"
    fi
}

strip_subshells() {
    _scan_subshells "$1" "strip"
}

extract_subshell_bodies() {
    _scan_subshells "$1" "extract"
}
