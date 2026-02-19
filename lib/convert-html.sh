#!/bin/bash
# convert-html.sh — Convert HTML files to PDF via Chromium headless
#
# Supported: .html, .htm
#
# Usage (sourced): convert_html INPUT_FILE OUTPUT_PDF [PAGE_SIZE]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Find a Chromium/Chrome binary
find_chrome() {
    local candidates=(
        google-chrome-stable
        google-chrome
        chromium-browser
        chromium
    )
    for cmd in "${candidates[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            echo "$cmd"
            return 0
        fi
    done
    return 1
}

convert_html() {
    local input_file="$1"
    local output_pdf="$2"
    local page_size="${3:-letter}"

    local chrome_bin
    chrome_bin=$(find_chrome)
    if [[ -z "$chrome_bin" ]]; then
        log_error "No Chromium or Chrome browser found. Install with: sudo apt-get install chromium-browser"
        return "$EXIT_MISSING_TOOL"
    fi

    local temp_dir
    temp_dir=$(make_temp_dir)

    # Resolve to absolute path for file:// URL
    local abs_path
    abs_path=$(realpath "$input_file")

    log_verbose "Converting HTML with $chrome_bin: $input_file"

    # Ensure output path is absolute (Chrome resolves relative to its own CWD)
    local abs_output
    abs_output=$(realpath -m "$output_pdf")

    # Chrome headless print-to-pdf
    # Note: --no-sandbox may be needed in containerized environments
    if ! "$chrome_bin" \
        --headless \
        --disable-gpu \
        --no-sandbox \
        --disable-software-rasterizer \
        --print-to-pdf="$abs_output" \
        --no-pdf-header-footer \
        "file://$abs_path" \
        >"$temp_dir/chrome_stdout.log" 2>"$temp_dir/chrome_stderr.log"; then
        log_error "Chrome PDF conversion failed for: $input_file"
        cat "$temp_dir/chrome_stderr.log" >&2
        return "$EXIT_CONVERSION_FAILED"
    fi

    if [[ ! -f "$abs_output" ]] || [[ ! -s "$abs_output" ]]; then
        log_error "Chrome produced no PDF output."
        cat "$temp_dir/chrome_stderr.log" >&2
        return "$EXIT_CONVERSION_FAILED"
    fi

    # Copy to the requested output path if different
    [[ "$abs_output" != "$(realpath -m "$output_pdf")" ]] && cp "$abs_output" "$output_pdf"

    log_verbose "HTML conversion complete: $output_pdf"
    return "$EXIT_OK"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 INPUT_FILE OUTPUT_PDF [letter|a4]"
        exit "$EXIT_USAGE"
    fi
    convert_html "$1" "$2" "${3:-letter}"
fi
