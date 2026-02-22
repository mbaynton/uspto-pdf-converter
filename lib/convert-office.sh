#!/bin/bash
# convert-office.sh — Convert Office documents to PDF via LibreOffice
#
# Supported: .doc, .docx, .xls, .xlsx, .ppt, .pptx, .odt, .ods, .odp, .rtf
#
# Usage (sourced): convert_office INPUT_FILE OUTPUT_PDF

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

convert_office() {
    local input_file="$1"
    local output_pdf="$2"

    # Check for LibreOffice - try 'libreoffice' first, then 'soffice' (macOS)
    local libreoffice_cmd=""
    if command -v libreoffice >/dev/null 2>&1; then
        libreoffice_cmd="libreoffice"
    elif command -v soffice >/dev/null 2>&1; then
        libreoffice_cmd="soffice"
    elif [[ -x "/Applications/LibreOffice.app/Contents/MacOS/soffice" ]]; then
        libreoffice_cmd="/Applications/LibreOffice.app/Contents/MacOS/soffice"
    else
        log_error "'libreoffice' is not installed. Install it with: sudo apt-get install libreoffice (or run install-deps.sh)"
        return "$EXIT_MISSING_TOOL"
    fi

    local temp_dir
    temp_dir=$(make_temp_dir)

    local basename
    basename=$(basename "$input_file")
    local name_no_ext="${basename%.*}"

    log_verbose "Converting Office document with LibreOffice: $input_file"

    # LibreOffice insists on writing to --outdir with its own chosen filename,
    # so we use a temp directory and move the result.
    if ! "$libreoffice_cmd" --headless --norestore --convert-to pdf \
        --outdir "$temp_dir" "$input_file" \
        >"$temp_dir/lo_stdout.log" 2>"$temp_dir/lo_stderr.log"; then
        log_error "LibreOffice conversion failed for: $input_file"
        cat "$temp_dir/lo_stderr.log" >&2
        return "$EXIT_CONVERSION_FAILED"
    fi

    local result_pdf="$temp_dir/${name_no_ext}.pdf"
    if [[ ! -f "$result_pdf" ]]; then
        log_error "LibreOffice did not produce expected output: $result_pdf"
        log_error "Files in temp dir: $(ls -1 "$temp_dir")"
        return "$EXIT_CONVERSION_FAILED"
    fi

    cp "$result_pdf" "$output_pdf"
    log_verbose "Office conversion complete: $output_pdf"
    return "$EXIT_OK"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 INPUT_FILE OUTPUT_PDF"
        exit "$EXIT_USAGE"
    fi
    convert_office "$1" "$2"
fi
