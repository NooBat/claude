#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BLOCK_REASON=""

# is_broad_home_path() — returns 0 if path targets a home directory or system root
# $1: path string to check
is_broad_home_path() {
    local p="$1"
    [[ "$p" == "/" || "$p" == "/home" || "$p" == "/etc" || "$p" == "~" || \
       "$p" == '~/'* || "$p" == '$HOME' || "$p" == '$HOME/'* || \
       "$p" == '${HOME}' || "$p" == '${HOME}/'* || \
       "$p" == /home/* || "$p" == /Users/* ]]
}

# cmd_contains_home_path() — returns 0 if command string contains a home-relative path to $1
# $1: relative path suffix (e.g. ".ssh/", ".netrc")
# Uses EFFECTIVE_CMD global
cmd_contains_home_path() {
    local suffix="$1"
    [[ "$EFFECTIVE_CMD" == *"~/$suffix"* ]] || \
    [[ "$EFFECTIVE_CMD" == *'$HOME/'"$suffix"* ]] || \
    [[ "$EFFECTIVE_CMD" == *'${HOME}/'"$suffix"* ]] || \
    [[ "$EFFECTIVE_CMD" == */Users/*/"$suffix"* ]] || \
    [[ "$EFFECTIVE_CMD" == */home/*/"$suffix"* ]]
}

# is_credential_hunting() — block reading sensitive credential files or searching for secrets
# $1: single command segment string
is_credential_hunting() {
    local cmd="$1"

    extract_base_cmd "$cmd" > /dev/null || return 1

    case "$BASE_CMD" in
        cat|head|tail|less|more)
            local path_suffix
            for path_suffix in .ssh/ .aws/ .config/gcloud/ .netrc .npmrc; do
                if cmd_contains_home_path "$path_suffix"; then
                    BLOCK_REASON="BLOCKED: '$cmd' accesses sensitive credential files — if you need this information, ask the user to provide it directly"
                    return 0
                fi
            done
            return 1
            ;;
        find)
            # Check: broad path AND -name matching sensitive patterns
            local args="${EFFECTIVE_CMD#find}"
            local -a tokens
            read -r -a tokens <<< "$args"

            # Extract path: first positional arg before any flag starting with -
            local path=""
            for tok in "${tokens[@]:-}"; do
                [[ "$tok" == -* ]] && break
                path="$tok"
            done

            if ! is_broad_home_path "$path"; then
                return 1
            fi

            # Check for -name with sensitive pattern
            local i=0
            local token_count="${#tokens[@]}"
            while (( i < token_count )); do
                if [[ "${tokens[$i]}" == "-name" ]] && (( i + 1 < token_count )); then
                    local name_val="${tokens[$((i + 1))]}"
                    # Strip quotes if present
                    name_val="${name_val//\'/}"
                    name_val="${name_val//\"/}"
                    if [[ "$name_val" == "*.key" || "$name_val" == "*.pem" || \
                          "$name_val" == "id_rsa" || "$name_val" == "*.p12" || \
                          "$name_val" == "credentials.json" ]]; then
                        BLOCK_REASON="BLOCKED: '$cmd' accesses sensitive credential files — if you need this information, ask the user to provide it directly"
                        return 0
                    fi
                fi
                (( i++ )) || true
            done
            return 1
            ;;
        grep|egrep)
            # Check: recursive flag AND sensitive keyword AND broad path
            local args="${EFFECTIVE_CMD#"$BASE_CMD"}"
            local -a tokens
            read -r -a tokens <<< "$args"

            # Check for recursive flag
            local has_recursive=0
            for tok in "${tokens[@]:-}"; do
                if [[ "$tok" == "--recursive" ]]; then
                    has_recursive=1
                    break
                fi
                # Check combined short flags for r or R (e.g., -ri, -rn, -Ri)
                if [[ "$tok" =~ ^-[a-zA-Z]*[rR] ]] || [[ "$tok" =~ ^-[rR] ]]; then
                    has_recursive=1
                    break
                fi
            done
            if (( ! has_recursive )); then
                return 1
            fi

            # Extract non-flag tokens (pattern and path arguments)
            local -a positional=()
            local skip_next=0
            for tok in "${tokens[@]:-}"; do
                if (( skip_next )); then
                    skip_next=0
                    continue
                fi
                # Skip flags that take a value argument
                if [[ "$tok" == "-e" || "$tok" == "-f" || "$tok" == "--include" || \
                      "$tok" == "--exclude" || "$tok" == "-m" || "$tok" == "--max-count" ]]; then
                    skip_next=1
                    continue
                fi
                [[ "$tok" == -* ]] && continue
                positional+=("$tok")
            done

            # Need at least 2 positional args (pattern + path)
            if (( ${#positional[@]} < 2 )); then
                return 1
            fi

            # Check if pattern contains sensitive keyword
            local pattern="${positional[0]}"
            local has_sensitive=0
            if [[ "$pattern" =~ password|secret|token|api_key|credential ]]; then
                has_sensitive=1
            fi
            if (( ! has_sensitive )); then
                return 1
            fi

            # Check if any path arg is broad
            local idx=1
            while (( idx < ${#positional[@]} )); do
                local p="${positional[$idx]}"
                if is_broad_home_path "$p"; then
                    BLOCK_REASON="BLOCKED: '$cmd' accesses sensitive credential files — if you need this information, ask the user to provide it directly"
                    return 0
                fi
                (( idx++ )) || true
            done
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# is_network_exfiltration() — block sending local data to external servers
# $1: single command segment string
is_network_exfiltration() {
    local cmd="$1"

    extract_base_cmd "$cmd" > /dev/null || return 1

    case "$BASE_CMD" in
        curl)
            local args="${EFFECTIVE_CMD#curl}"
            local -a tokens
            read -r -a tokens <<< "$args"

            local token_count="${#tokens[@]}"
            local i=0
            while (( i < token_count )); do
                local tok="${tokens[$i]}"

                # Check --upload-file (both space-separated and =value forms) and -T
                if [[ "$tok" == "--upload-file" || "$tok" == "--upload-file="* || "$tok" == "-T" ]]; then
                    BLOCK_REASON="BLOCKED: '$cmd' would send local data to an external server — data exfiltration is not permitted"
                    return 0
                fi

                # Check data flags: -d, --data, --data-binary, --data-urlencode, --data-raw
                # Both space-separated (@file) and =@file forms
                if [[ "$tok" == "-d" || "$tok" == "--data" || "$tok" == "--data-binary" || \
                      "$tok" == "--data-urlencode" || "$tok" == "--data-raw" ]]; then
                    if (( i + 1 < token_count )); then
                        local next="${tokens[$((i + 1))]}"
                        if [[ "$next" == @* ]]; then
                            BLOCK_REASON="BLOCKED: '$cmd' would send local data to an external server — data exfiltration is not permitted"
                            return 0
                        fi
                    fi
                fi
                # --data*=@file (inline = forms)
                if [[ "$tok" == "--data=@"* || "$tok" == "--data-binary=@"* || \
                      "$tok" == "--data-urlencode=@"* || "$tok" == "--data-raw=@"* ]]; then
                    BLOCK_REASON="BLOCKED: '$cmd' would send local data to an external server — data exfiltration is not permitted"
                    return 0
                fi

                # Check -F/--form/--form-string with =@ (form file upload)
                if [[ "$tok" == "-F" || "$tok" == "--form" || "$tok" == "--form-string" ]]; then
                    if (( i + 1 < token_count )); then
                        local next="${tokens[$((i + 1))]}"
                        if [[ "$next" == *=@* ]]; then
                            BLOCK_REASON="BLOCKED: '$cmd' would send local data to an external server — data exfiltration is not permitted"
                            return 0
                        fi
                    fi
                fi
                # -F embedded in same token: -Ffile=@secret.txt
                if [[ "$tok" == -F*=@* ]]; then
                    BLOCK_REASON="BLOCKED: '$cmd' would send local data to an external server — data exfiltration is not permitted"
                    return 0
                fi

                # Check for combined form like -d@file (no space)
                if [[ "$tok" =~ ^-d@ ]]; then
                    BLOCK_REASON="BLOCKED: '$cmd' would send local data to an external server — data exfiltration is not permitted"
                    return 0
                fi

                (( i++ )) || true
            done
            return 1
            ;;
        wget)
            if [[ "$EFFECTIVE_CMD" =~ (^|[[:space:]])--post-file([[:space:]]|$) ]]; then
                BLOCK_REASON="BLOCKED: '$cmd' would send local data to an external server — data exfiltration is not permitted"
                return 0
            fi
            return 1
            ;;
        nc|ncat|netcat)
            BLOCK_REASON="BLOCKED: '$cmd' would send local data to an external server — data exfiltration is not permitted"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# is_exfiltration() — main per-segment entry point
# $1: single command segment string
is_exfiltration() {
    local cmd="$1"

    if is_credential_hunting "$cmd"; then
        return 0
    fi

    if is_network_exfiltration "$cmd"; then
        return 0
    fi

    # Handle sudo: strip and recurse
    # BASE_CMD/EFFECTIVE_CMD already set by is_network_exfiltration's extract_base_cmd call
    if [[ "$BASE_CMD" == "sudo" ]]; then
        local remainder="${EFFECTIVE_CMD#sudo}"
        remainder="${remainder#"${remainder%%[![:space:]]*}"}"  # ltrim
        if [[ -z "$remainder" ]]; then
            return 1
        fi
        is_exfiltration "$remainder"
        return $?
    fi

    return 1
}

# check_cross_segment_exfil() — cross-segment exfiltration patterns
# Uses global CROSS_SEGMENTS array (set by caller) to avoid eval on untrusted data
check_cross_segment_exfil() {
    local count=${#CROSS_SEGMENTS[@]}

    local i=0
    while (( i + 1 < count )); do
        local seg_a="${CROSS_SEGMENTS[$i]}"
        local seg_b="${CROSS_SEGMENTS[$((i + 1))]}"

        # Extract base commands for both segments
        extract_base_cmd "$seg_a" > /dev/null || { (( i++ )) || true; continue; }
        local base_a="$BASE_CMD"
        local effective_a="$EFFECTIVE_CMD"

        extract_base_cmd "$seg_b" > /dev/null || { (( i++ )) || true; continue; }
        local base_b="$BASE_CMD"
        local effective_b="$EFFECTIVE_CMD"

        # Pattern: env | grep <credential keyword>
        if [[ "$base_a" == "env" ]]; then
            # Check that env is bare or only has flags (starts with -)
            local env_args="${effective_a#env}"
            env_args="${env_args#"${env_args%%[![:space:]]*}"}"  # ltrim
            local env_only_flags=1
            if [[ -n "$env_args" ]]; then
                local -a env_tokens
                read -r -a env_tokens <<< "$env_args"
                for tok in "${env_tokens[@]:-}"; do
                    if [[ "$tok" != -* ]]; then
                        env_only_flags=0
                        break
                    fi
                done
            fi

            if (( env_only_flags )) && [[ "$base_b" == "grep" || "$base_b" == "egrep" ]]; then
                # Check if grep args contain credential keyword (case-insensitive)
                local grep_args="${effective_b#"$base_b"}"
                if [[ "$grep_args" =~ [Tt][Oo][Kk][Ee][Nn] ]] || \
                   [[ "$grep_args" =~ [Ss][Ee][Cc][Rr][Ee][Tt] ]] || \
                   [[ "$grep_args" =~ [Kk][Ee][Yy] ]] || \
                   [[ "$grep_args" =~ [Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd] ]] || \
                   [[ "$grep_args" =~ [Aa][Pp][Ii] ]]; then
                    BLOCK_REASON="BLOCKED: piping 'env' to grep for credentials is not permitted — if you need this information, ask the user to provide it directly"
                    return 0
                fi
            fi
        fi

        # Pattern: base64 | curl
        if [[ "$base_a" == "base64" && "$base_b" == "curl" ]]; then
            BLOCK_REASON="BLOCKED: encoding and exfiltrating data via 'base64 | curl' is not permitted — data exfiltration is not allowed"
            return 0
        fi

        (( i++ )) || true
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

    # Collect all segments into the global array used by check_cross_segment_exfil
    CROSS_SEGMENTS=()
    while IFS= read -r segment; do
        CROSS_SEGMENTS+=("$segment")
    done < <(parse_chain "$COMMAND")

    # Per-segment checks
    for segment in "${CROSS_SEGMENTS[@]}"; do
        if is_exfiltration "$segment"; then
            json_deny "PreToolUse" "$BLOCK_REASON"
        fi
    done

    # Cross-segment checks
    if check_cross_segment_exfil; then
        json_deny "PreToolUse" "$BLOCK_REASON"
    fi

    exit 0
fi
