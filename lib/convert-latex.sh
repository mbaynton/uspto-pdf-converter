#!/bin/bash
# convert-latex.sh — Convert LaTeX documents to PDF
#
# Supported: .tex, .latex
#
# Uses pdflatex by default; falls back to xelatex for Unicode support.
# Runs twice to resolve cross-references.
#
# Usage (sourced): convert_latex INPUT_FILE OUTPUT_PDF

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

convert_latex() {
    local input_file="$1"
    local output_pdf="$2"

    local temp_dir
    temp_dir=$(make_temp_dir)

    local abs_input
    abs_input=$(realpath "$input_file")
    local basename
    basename=$(basename "$input_file")
    local name_no_ext="${basename%.*}"

    # Copy input to temp dir so auxiliary files don't pollute the source directory
    cp "$abs_input" "$temp_dir/"

    # Also copy any files in the same directory (for \input, \include, images, etc.)
    local input_dir
    input_dir=$(dirname "$abs_input")
    # Only copy if the input directory has other files
    if [[ "$input_dir" != "$temp_dir" ]]; then
        cp -r "$input_dir"/* "$temp_dir/" 2>/dev/null || true
    fi

    local latex_engine="pdflatex"
    if ! command -v pdflatex &>/dev/null; then
        if command -v xelatex &>/dev/null; then
            latex_engine="xelatex"
        else
            log_error "Neither pdflatex nor xelatex found. Install with: sudo apt-get install texlive-latex-base"
            return "$EXIT_MISSING_TOOL"
        fi
    fi

    log_verbose "Converting LaTeX with $latex_engine: $input_file"

    # Run twice for cross-references
    local attempt
    for attempt in 1 2; do
        if ! "$latex_engine" \
            -interaction=nonstopmode \
            -output-directory="$temp_dir" \
            "$temp_dir/$basename" \
            >"$temp_dir/latex_stdout_$attempt.log" 2>"$temp_dir/latex_stderr_$attempt.log"; then
            if [[ "$attempt" -eq 1 ]]; then
                # First pass failure with pdflatex — try xelatex if available
                if [[ "$latex_engine" == "pdflatex" ]] && command -v xelatex &>/dev/null; then
                    log_warn "pdflatex failed, trying xelatex..."
                    latex_engine="xelatex"
                    continue
                fi
            fi
            log_error "LaTeX compilation failed for: $input_file"
            # Show relevant error lines from log
            grep -A 2 "^!" "$temp_dir/latex_stdout_$attempt.log" >&2 2>/dev/null || \
                cat "$temp_dir/latex_stderr_$attempt.log" >&2
            return "$EXIT_CONVERSION_FAILED"
        fi
    done

    local result_pdf="$temp_dir/${name_no_ext}.pdf"
    if [[ ! -f "$result_pdf" ]]; then
        log_error "LaTeX did not produce expected output: $result_pdf"
        return "$EXIT_CONVERSION_FAILED"
    fi

    cp "$result_pdf" "$output_pdf"
    log_verbose "LaTeX conversion complete: $output_pdf"
    return "$EXIT_OK"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 INPUT_FILE OUTPUT_PDF"
        exit "$EXIT_USAGE"
    fi
    convert_latex "$1" "$2"
fi
