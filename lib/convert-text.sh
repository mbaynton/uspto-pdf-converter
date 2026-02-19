#!/bin/bash
# convert-text.sh — Convert text-based documents to PDF via Pandoc
#
# Supported: .md, .markdown, .txt, .rst
#
# Uses pandoc with pdflatex backend for proper font embedding and typesetting.
#
# Usage (sourced): convert_text INPUT_FILE OUTPUT_PDF [PAGE_SIZE]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

convert_text() {
    local input_file="$1"
    local output_pdf="$2"
    local page_size="${3:-letter}"

    require_tool pandoc pandoc || return $?
    require_tool pdflatex "texlive-latex-base texlive-fonts-recommended" || return $?

    local temp_dir
    temp_dir=$(make_temp_dir)

    local paper_var
    case "$page_size" in
        letter) paper_var="letterpaper" ;;
        a4)     paper_var="a4paper" ;;
    esac

    log_verbose "Converting text document with Pandoc: $input_file"

    # Detect input format from extension
    local ext="${input_file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    local pandoc_from=""
    case "$ext" in
        md|markdown) pandoc_from="--from=markdown" ;;
        rst)         pandoc_from="--from=rst" ;;
        txt)         pandoc_from="--from=markdown" ;; # treat plain text as markdown
    esac

    if ! pandoc \
        $pandoc_from \
        --pdf-engine=pdflatex \
        --variable="papersize:$paper_var" \
        --variable="geometry:margin=1in" \
        --variable="documentclass:article" \
        --variable="fontsize:12pt" \
        -o "$output_pdf" \
        "$input_file" 2>"$temp_dir/pandoc_err.log"; then
        log_error "Pandoc conversion failed for: $input_file"
        cat "$temp_dir/pandoc_err.log" >&2
        return "$EXIT_CONVERSION_FAILED"
    fi

    if [[ ! -f "$output_pdf" ]] || [[ ! -s "$output_pdf" ]]; then
        log_error "Pandoc produced no output."
        return "$EXIT_CONVERSION_FAILED"
    fi

    log_verbose "Text conversion complete: $output_pdf"
    return "$EXIT_OK"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 INPUT_FILE OUTPUT_PDF [letter|a4]"
        exit "$EXIT_USAGE"
    fi
    convert_text "$1" "$2" "${3:-letter}"
fi
