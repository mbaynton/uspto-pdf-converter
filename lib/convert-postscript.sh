#!/bin/bash
# convert-postscript.sh — Convert PostScript/EPS files to PDF via Ghostscript
#
# Supported: .ps, .eps
#
# Usage (sourced): convert_postscript INPUT_FILE OUTPUT_PDF

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

convert_postscript() {
    local input_file="$1"
    local output_pdf="$2"

    require_tool gs ghostscript || return $?

    local temp_dir
    temp_dir=$(make_temp_dir)

    log_verbose "Converting PostScript with Ghostscript: $input_file"

    if ! gs \
        -dBATCH \
        -dNOPAUSE \
        -dSAFER \
        -dQUIET \
        -sDEVICE=pdfwrite \
        -dCompatibilityLevel=1.6 \
        -dEmbedAllFonts=true \
        -sOutputFile="$output_pdf" \
        "$input_file" 2>"$temp_dir/gs_err.log"; then
        log_error "Ghostscript PS-to-PDF conversion failed:"
        cat "$temp_dir/gs_err.log" >&2
        return "$EXIT_CONVERSION_FAILED"
    fi

    if [[ ! -f "$output_pdf" ]] || [[ ! -s "$output_pdf" ]]; then
        log_error "Ghostscript produced no output."
        return "$EXIT_CONVERSION_FAILED"
    fi

    log_verbose "PostScript conversion complete: $output_pdf"
    return "$EXIT_OK"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 INPUT_FILE OUTPUT_PDF"
        exit "$EXIT_USAGE"
    fi
    convert_postscript "$1" "$2"
fi
