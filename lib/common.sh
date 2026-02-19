#!/bin/bash
# common.sh — Shared utilities for USPTO PDF converter

# Guard against multiple sourcing
[[ -n "${_USPTO_COMMON_LOADED:-}" ]] && return 0
_USPTO_COMMON_LOADED=1

# Exit codes
readonly EXIT_OK=0
readonly EXIT_UNKNOWN_FORMAT=1
readonly EXIT_MISSING_TOOL=2
readonly EXIT_CONVERSION_FAILED=3
readonly EXIT_NORMALIZATION_FAILED=4
readonly EXIT_VALIDATION_FAILED=5
readonly EXIT_USAGE=6

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly BOLD='\033[1m'
    readonly RESET='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BOLD=''
    readonly RESET=''
fi

# Logging
VERBOSE="${VERBOSE:-0}"

log_info() {
    echo -e "${BOLD}[INFO]${RESET} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${RESET} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $*" >&2
}

log_pass() {
    echo -e "  ${GREEN}PASS${RESET}: $*"
}

log_fail() {
    echo -e "  ${RED}FAIL${RESET}: $*"
}

log_verbose() {
    if [[ "$VERBOSE" -ge 1 ]]; then
        echo -e "${BOLD}[DEBUG]${RESET} $*"
    fi
}

# Check that a required tool is available
require_tool() {
    local tool="$1"
    local package="${2:-$1}"
    if ! command -v "$tool" &>/dev/null; then
        log_error "'$tool' is not installed. Install it with: sudo apt-get install $package (or run install-deps.sh)"
        return "$EXIT_MISSING_TOOL"
    fi
}

# Create a temp directory and register cleanup
_CLEANUP_DIRS=()
make_temp_dir() {
    local dir
    dir=$(mktemp -d "${TMPDIR:-/tmp}/uspto-pdf-XXXXXX")
    _CLEANUP_DIRS+=("$dir")
    echo "$dir"
}

cleanup_temp_dirs() {
    for dir in "${_CLEANUP_DIRS[@]}"; do
        [[ -d "$dir" ]] && rm -rf "$dir"
    done
}
trap cleanup_temp_dirs EXIT

# Detect format from file extension, with `file` command fallback
detect_format() {
    local filepath="$1"
    local ext="${filepath##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    case "$ext" in
        pdf)                          echo "pdf" ;;
        doc|docx|odt|rtf)            echo "office" ;;
        xls|xlsx|ods)                 echo "office" ;;
        ppt|pptx|odp)                echo "office" ;;
        jpg|jpeg|png|tiff|tif|bmp|gif) echo "image" ;;
        md|markdown|rst)              echo "text" ;;
        txt)                          echo "text" ;;
        html|htm)                     echo "html" ;;
        tex|latex)                    echo "latex" ;;
        ps|eps)                       echo "postscript" ;;
        *)
            # Fallback: use file command
            local mime
            mime=$(file --brief --mime-type "$filepath" 2>/dev/null)
            case "$mime" in
                application/pdf)                        echo "pdf" ;;
                application/msword|application/vnd.*)   echo "office" ;;
                image/*)                                echo "image" ;;
                text/html)                              echo "html" ;;
                text/x-tex)                             echo "latex" ;;
                application/postscript)                 echo "postscript" ;;
                text/*)                                 echo "text" ;;
                *)                                      echo "unknown" ;;
            esac
            ;;
    esac
}

# Resolve the directory this script lives in (for finding lib/ siblings)
resolve_lib_dir() {
    local source="${BASH_SOURCE[1]}"
    local dir
    while [[ -L "$source" ]]; do
        dir=$(cd -P "$(dirname "$source")" &>/dev/null && pwd)
        source=$(readlink "$source")
        [[ "$source" != /* ]] && source="$dir/$source"
    done
    dir=$(cd -P "$(dirname "$source")" &>/dev/null && pwd)
    # If called from the project root scripts, lib/ is a sibling
    if [[ -d "$dir/lib" ]]; then
        echo "$dir/lib"
    else
        # Called from within lib/
        echo "$dir"
    fi
}
