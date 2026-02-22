#!/bin/bash
# split.sh — Split large PDFs into USPTO-compliant size chunks
#
# Usage (sourced): split_pdf_by_size INPUT_PDF OUTPUT_BASE [MAX_SIZE]
#   INPUT_PDF:   Path to the PDF to potentially split
#   OUTPUT_BASE: Output file path without .pdf extension (e.g., "/tmp/document")
#   MAX_SIZE:    Maximum size in bytes (default: MAX_PDF_SIZE_BYTES from common.sh)
#
# Returns: Newline-separated list of output file paths to stdout
#          If no split needed: returns single file path
#          If split needed: returns multiple paths with _partN.pdf suffix

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

split_pdf_by_size() {
    local input_pdf="$1"
    local output_base="$2"
    local max_size="${3:-$MAX_PDF_SIZE_BYTES}"

    require_tool qpdf qpdf || return $?
    require_tool pdfinfo poppler-utils || return $?

    # Check file size
    local file_size
    file_size=$(get_file_size_bytes "$input_pdf")

    if [[ -z "$file_size" ]]; then
        log_error "Could not determine file size for: $input_pdf"
        return "$EXIT_CONVERSION_FAILED"
    fi

    # If under limit, no split needed
    if [[ "$file_size" -le "$max_size" ]]; then
        local output_file="${output_base}.pdf"
        cp "$input_pdf" "$output_file"
        echo "$output_file"
        return "$EXIT_OK"
    fi

    # File exceeds limit, need to split
    log_info "File exceeds size limit ($(numfmt --to=iec-i --suffix=B "$file_size" 2>/dev/null || echo "${file_size} bytes")), splitting..."

    # Get page count
    local page_count
    page_count=$(pdfinfo "$input_pdf" 2>/dev/null | tr -d '\0' | grep "^Pages:" | awk '{print $2}')
    page_count="${page_count:-0}"

    if [[ "$page_count" -eq 0 ]]; then
        log_error "Could not determine page count for: $input_pdf"
        return "$EXIT_CONVERSION_FAILED"
    fi

    # Check for single-page PDF that's too large
    if [[ "$page_count" -eq 1 ]]; then
        local size_mib
        size_mib=$(awk "BEGIN {printf \"%.1f\", $file_size / 1024 / 1024}")
        log_error "Single-page PDF exceeds size limit (${size_mib} MiB) and cannot be split on page boundaries"
        return "$EXIT_CONVERSION_FAILED"
    fi

    # Calculate initial pages per part with 90% safety margin
    local avg_size_per_page=$((file_size / page_count))
    local safe_max_size=$((max_size * 90 / 100))  # 90% of max size
    local initial_pages_per_part=$((safe_max_size / avg_size_per_page))

    # Ensure at least 1 page per part
    [[ "$initial_pages_per_part" -lt 1 ]] && initial_pages_per_part=1

    log_verbose "File size: $(numfmt --to=iec-i --suffix=B "$file_size" 2>/dev/null || echo "${file_size} bytes"), Pages: $page_count, Initial pages per part: $initial_pages_per_part"

    # Create temp directory for splitting operations
    local temp_dir
    temp_dir=$(make_temp_dir)

    # Split into parts
    local part_num=1
    local start_page=1
    local split_files=()

    while [[ "$start_page" -le "$page_count" ]]; do
        local pages_for_this_part="$initial_pages_per_part"
        local end_page=$((start_page + pages_for_this_part - 1))
        [[ "$end_page" -gt "$page_count" ]] && end_page="$page_count"

        local part_file="${output_base}_part${part_num}.pdf"
        local attempt=1
        local max_attempts=20  # Prevent infinite loop

        # Try to create a part that fits within size limit
        while [[ "$attempt" -le "$max_attempts" ]]; do
            log_verbose "Creating part $part_num (attempt $attempt): pages $start_page-$end_page"

            # Create the part
            local qpdf_rc=0
            qpdf "$input_pdf" --pages . "$start_page-$end_page" -- "$part_file" 2>"$temp_dir/qpdf_part${part_num}_err.log" || qpdf_rc=$?

            # Check qpdf success (0 = success, 3 = warnings but output produced)
            if [[ "$qpdf_rc" -ne 0 && "$qpdf_rc" -ne 3 ]] || [[ ! -f "$part_file" ]] || [[ ! -s "$part_file" ]]; then
                log_error "Failed to create part $part_num (qpdf exit code: $qpdf_rc)"
                [[ -f "$temp_dir/qpdf_part${part_num}_err.log" ]] && cat "$temp_dir/qpdf_part${part_num}_err.log" >&2
                return "$EXIT_CONVERSION_FAILED"
            fi

            # Check the size of the created part
            local part_size
            part_size=$(get_file_size_bytes "$part_file")

            if [[ "$part_size" -le "$max_size" ]]; then
                # Part fits! Keep it and move on
                log_verbose "Part $part_num complete: $(numfmt --to=iec-i --suffix=B "$part_size" 2>/dev/null || echo "${part_size} bytes"), pages $start_page-$end_page"
                split_files+=("$part_file")
                start_page=$((end_page + 1))
                part_num=$((part_num + 1))
                break
            else
                # Part is too large, need to retry with fewer pages
                log_verbose "Part $part_num too large ($(numfmt --to=iec-i --suffix=B "$part_size" 2>/dev/null || echo "${part_size} bytes")), reducing page count..."

                # Delete the oversized part
                rm -f "$part_file"

                # Check if we're down to a single page
                local current_page_count=$((end_page - start_page + 1))
                if [[ "$current_page_count" -eq 1 ]]; then
                    log_error "Single page (page $start_page) exceeds size limit and cannot be split further"
                    return "$EXIT_CONVERSION_FAILED"
                fi

                # Reduce page count by 20% (or at least by 1)
                local reduction=$((current_page_count / 5))
                [[ "$reduction" -lt 1 ]] && reduction=1
                pages_for_this_part=$((current_page_count - reduction))
                [[ "$pages_for_this_part" -lt 1 ]] && pages_for_this_part=1

                end_page=$((start_page + pages_for_this_part - 1))
                [[ "$end_page" -gt "$page_count" ]] && end_page="$page_count"

                attempt=$((attempt + 1))
            fi
        done

        # Check if we exceeded max attempts
        if [[ "$attempt" -gt "$max_attempts" ]]; then
            log_error "Failed to create part $part_num within size limit after $max_attempts attempts"
            return "$EXIT_CONVERSION_FAILED"
        fi
    done

    # Log summary
    log_info "Split complete: ${#split_files[@]} parts created"

    # Output the list of files
    printf '%s\n' "${split_files[@]}"
    return "$EXIT_OK"
}

# Allow running this script directly for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 INPUT_PDF OUTPUT_BASE [MAX_SIZE_BYTES]"
        exit "$EXIT_USAGE"
    fi
    split_pdf_by_size "$1" "$2" "${3:-$MAX_PDF_SIZE_BYTES}"
fi
