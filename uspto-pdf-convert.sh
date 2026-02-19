#!/bin/bash
# uspto-pdf-convert.sh — Convert documents to USPTO EFS-Web compliant PDFs
#
# Usage:
#   uspto-pdf-convert.sh [options] INPUT_FILE [INPUT_FILE ...]
#
# Options:
#   -o DIR      Output directory (default: current directory)
#   -p SIZE     Page size: letter or a4 (default: letter)
#   -n          Skip post-conversion validation
#   -v          Verbose output
#   -h          Show help
#
# Supported input formats:
#   Office:      .doc, .docx, .xls, .xlsx, .ppt, .pptx, .odt, .ods, .odp, .rtf
#   Images:      .jpg, .jpeg, .png, .tiff, .tif, .bmp, .gif
#   Text:        .md, .markdown, .txt, .rst
#   HTML:        .html, .htm
#   LaTeX:       .tex, .latex
#   PostScript:  .ps, .eps
#   PDF:         .pdf (re-normalizes for compliance)

set -euo pipefail

# PROJECT_ROOT is the canonical location of this script; SCRIPT_DIR in library
# scripts may point to lib/ — so we keep our own variable.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$PROJECT_ROOT/lib"

source "$LIB_DIR/common.sh"
source "$LIB_DIR/normalize.sh"
source "$LIB_DIR/convert-office.sh"
source "$LIB_DIR/convert-image.sh"
source "$LIB_DIR/convert-text.sh"
source "$LIB_DIR/convert-html.sh"
source "$LIB_DIR/convert-latex.sh"
source "$LIB_DIR/convert-postscript.sh"

# Defaults
OUTPUT_DIR="."
PAGE_SIZE="letter"
SKIP_VALIDATION=0
VERBOSE=0

usage() {
    cat <<'EOF'
Usage: uspto-pdf-convert.sh [options] INPUT_FILE [INPUT_FILE ...]

Convert documents to USPTO EFS-Web compliant PDFs.

Options:
  -o DIR      Output directory (default: current directory)
  -p SIZE     Page size: letter or a4 (default: letter)
  -n          Skip post-conversion validation
  -v          Verbose output
  -h          Show help

Supported input formats:
  Office:      .doc, .docx, .xls, .xlsx, .ppt, .pptx, .odt, .ods, .odp, .rtf
  Images:      .jpg, .jpeg, .png, .tiff, .tif, .bmp, .gif
  Text:        .md, .markdown, .txt, .rst
  HTML:        .html, .htm
  LaTeX:       .tex, .latex
  PostScript:  .ps, .eps
  PDF:         .pdf (re-normalizes for compliance)
EOF
}

# Convert a single file and return 0 on success
convert_single_file() {
    local input_file="$1"
    local output_dir="$2"
    local page_size="$3"
    local skip_validation="$4"

    if [[ ! -f "$input_file" ]]; then
        log_error "File not found: $input_file"
        return "$EXIT_CONVERSION_FAILED"
    fi

    local basename
    basename=$(basename "$input_file")
    local name_no_ext="${basename%.*}"
    local output_pdf="$output_dir/${name_no_ext}.pdf"

    # Don't overwrite input if input is a PDF in the same directory
    if [[ -f "$output_pdf" ]] && [[ "$(realpath "$input_file")" == "$(realpath "$output_pdf")" ]]; then
        output_pdf="$output_dir/${name_no_ext}.compliant.pdf"
    fi

    local format
    format=$(detect_format "$input_file")

    if [[ "$format" == "unknown" ]]; then
        log_error "Unsupported format: $input_file"
        log_error "Run with -h to see supported formats."
        return "$EXIT_UNKNOWN_FORMAT"
    fi

    log_info "Converting: $input_file (format: $format)"

    local temp_dir
    temp_dir=$(make_temp_dir)
    local raw_pdf="$temp_dir/raw.pdf"
    local normalized_pdf="$temp_dir/normalized.pdf"

    # Step 1: Format-specific conversion to raw PDF
    local rc=0
    case "$format" in
        office)
            convert_office "$input_file" "$raw_pdf" || rc=$?
            ;;
        image)
            convert_image "$input_file" "$raw_pdf" "$page_size" || rc=$?
            ;;
        text)
            convert_text "$input_file" "$raw_pdf" "$page_size" || rc=$?
            ;;
        html)
            convert_html "$input_file" "$raw_pdf" "$page_size" || rc=$?
            ;;
        latex)
            convert_latex "$input_file" "$raw_pdf" || rc=$?
            ;;
        postscript)
            convert_postscript "$input_file" "$raw_pdf" || rc=$?
            ;;
        pdf)
            cp "$input_file" "$raw_pdf"
            ;;
    esac

    if [[ "$rc" -ne 0 ]]; then
        log_error "Format conversion failed for: $input_file"
        return "$rc"
    fi

    # Step 2: Normalize for USPTO compliance
    log_info "Normalizing for USPTO compliance..."
    if ! normalize_pdf "$raw_pdf" "$normalized_pdf" "$page_size"; then
        log_error "Normalization failed for: $input_file"
        return "$EXIT_NORMALIZATION_FAILED"
    fi

    # Step 3: Validate (unless skipped)
    if [[ "$skip_validation" -eq 0 ]]; then
        local validator="$PROJECT_ROOT/uspto-pdf-validate.sh"
        if [[ -x "$validator" ]]; then
            log_info "Validating output..."
            if ! "$validator" "$normalized_pdf"; then
                log_warn "Validation FAILED for: $input_file"
                log_warn "The output PDF may not be fully compliant."
                # Still produce the output, but warn and use non-zero exit
                cp "$normalized_pdf" "$output_pdf"
                log_info "Output (non-compliant): $output_pdf"
                return "$EXIT_VALIDATION_FAILED"
            fi
        else
            log_verbose "Validator not found at $validator, skipping validation."
        fi
    fi

    cp "$normalized_pdf" "$output_pdf"
    log_info "Output: $output_pdf"
    return "$EXIT_OK"
}

# --- Main ---
main() {
    local input_files=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -p)
                PAGE_SIZE="$2"
                if [[ "$PAGE_SIZE" != "letter" && "$PAGE_SIZE" != "a4" ]]; then
                    log_error "Invalid page size: $PAGE_SIZE (use 'letter' or 'a4')"
                    exit "$EXIT_USAGE"
                fi
                shift 2
                ;;
            -n)
                SKIP_VALIDATION=1
                shift
                ;;
            -v)
                VERBOSE=1
                export VERBOSE
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit "$EXIT_USAGE"
                ;;
            *)
                input_files+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#input_files[@]} -eq 0 ]]; then
        log_error "No input files specified."
        usage
        exit "$EXIT_USAGE"
    fi

    # Create output directory if needed
    mkdir -p "$OUTPUT_DIR"

    local total=${#input_files[@]}
    local succeeded=0
    local failed=0

    for input_file in "${input_files[@]}"; do
        if convert_single_file "$input_file" "$OUTPUT_DIR" "$PAGE_SIZE" "$SKIP_VALIDATION"; then
            succeeded=$((succeeded + 1))
        else
            failed=$((failed + 1))
        fi
    done

    # Summary
    if [[ "$total" -gt 1 ]]; then
        echo ""
        log_info "Summary: $succeeded/$total succeeded, $failed/$total failed."
    fi

    if [[ "$failed" -gt 0 ]]; then
        exit "$EXIT_CONVERSION_FAILED"
    fi
    exit "$EXIT_OK"
}

main "$@"
