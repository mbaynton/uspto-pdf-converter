#!/bin/bash
# normalize.sh — Post-processing pipeline for USPTO compliance
#
# Uses pdftocairo for page size normalization and font re-embedding,
# then qpdf for PDF version downgrade and cleanup.
#
# Usage: normalize_pdf INPUT_PDF OUTPUT_PDF [PAGE_SIZE]
#   PAGE_SIZE: "letter" (default) or "a4"
#
# This script is sourced by other scripts; it provides the normalize_pdf function.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

normalize_pdf() {
    local input_pdf="$1"
    local output_pdf="$2"
    local page_size="${3:-letter}"

    require_tool pdftocairo poppler-utils || return $?
    require_tool qpdf qpdf || return $?

    local temp_dir
    temp_dir=$(make_temp_dir)
    local cairo_out="$temp_dir/cairo_resized.pdf"
    local qpdf_out="$temp_dir/qpdf_final.pdf"

    # Validate page_size argument
    case "$page_size" in
        letter|a4) ;;
        *)
            log_error "Unknown page size: $page_size (use 'letter' or 'a4')"
            return "$EXIT_NORMALIZATION_FAILED"
            ;;
    esac

    # --- Step 0: Rotate landscape pages to portrait ---
    # Detect pages whose effective orientation is landscape (considering both
    # MediaBox dimensions and any existing /Rotate flag) and set a +90° rotation
    # so that pdftocairo will render them as portrait.
    local cairo_input="$input_pdf"
    local page_count
    page_count=$(pdfinfo "$input_pdf" 2>/dev/null | tr -d '\0' | grep "^Pages:" | awk '{print $2}')
    page_count="${page_count:-0}"

    if [[ "$page_count" -gt 0 ]]; then
        # Collect landscape page numbers in one pass.
        # A page is effectively landscape when:
        #   rot 0° or 180°: MediaBox width > height
        #   rot 90° or 270°: MediaBox height > width
        local landscape_pages
        landscape_pages=$(pdfinfo -f 1 -l "$page_count" "$input_pdf" 2>/dev/null | tr -d '\0' | awk '
            /^Page[[:space:]]+[0-9]+[[:space:]]+size:/ {
                page = $2; w = $4; h = $6
            }
            /^Page[[:space:]]+[0-9]+[[:space:]]+rot:/ {
                rot = $4
                if ((rot == 0 || rot == 180) && w > h + 1) {
                    pages = pages (pages ? "," : "") page
                } else if ((rot == 90 || rot == 270) && h > w + 1) {
                    pages = pages (pages ? "," : "") page
                }
            }
            END { print pages }
        ')

        if [[ -n "$landscape_pages" ]]; then
            log_verbose "Rotating landscape pages to portrait: $landscape_pages"
            local rotated_pdf="$temp_dir/rotated.pdf"
            local rot_rc=0
            qpdf --rotate=+90:"$landscape_pages" \
                "$input_pdf" "$rotated_pdf" 2>"$temp_dir/rotate_err.log" || rot_rc=$?
            if [[ "$rot_rc" -ne 0 && "$rot_rc" -ne 3 ]] || [[ ! -s "$rotated_pdf" ]]; then
                log_warn "Landscape rotation failed (exit $rot_rc), proceeding without rotation"
            else
                cairo_input="$rotated_pdf"
            fi
        fi
    fi

    # --- Step 1: pdftocairo ---
    # Normalizes page size to target, re-embeds all fonts (including Base 14
    # substitutes like NimbusSans for Helvetica), and flattens layers.
    log_verbose "Running pdftocairo (page_size=$page_size)..."

    local cairo_rc=0
    pdftocairo -pdf -paper "$page_size" -expand \
        "$cairo_input" "$cairo_out" 2>"$temp_dir/cairo_err.log" || cairo_rc=$?

    if [[ "$cairo_rc" -ne 0 ]] || [[ ! -f "$cairo_out" ]] || [[ ! -s "$cairo_out" ]]; then
        log_error "pdftocairo failed (exit code $cairo_rc):"
        cat "$temp_dir/cairo_err.log" >&2
        return "$EXIT_NORMALIZATION_FAILED"
    fi

    # --- Step 2: qpdf ---
    # Force PDF version <= 1.6, flatten annotations, remove attachments,
    # and decrypt if needed.
    log_verbose "Running qpdf post-processing..."

    local qpdf_args=(
        --force-version=1.6
        --flatten-annotations=all
    )

    # Decrypt if encrypted
    if qpdf --is-encrypted "$cairo_out" 2>/dev/null; then
        log_warn "PDF is encrypted after pdftocairo; attempting to decrypt..."
        qpdf_args+=(--decrypt)
    fi

    # Remove any attachments individually
    local att_output
    att_output=$(qpdf --list-attachments "$cairo_out" 2>/dev/null || true)
    local attachment_keys
    attachment_keys=$(echo "$att_output" | grep -v 'no embedded files' | grep -v '^\s*$' | sed 's/:.*$//' | xargs -r || true)
    if [[ -n "$attachment_keys" ]]; then
        log_verbose "Removing attachments..."
        for key in $attachment_keys; do
            qpdf_args+=("--remove-attachment=$key")
        done
    fi

    local qpdf_rc=0
    qpdf "${qpdf_args[@]}" "$cairo_out" "$qpdf_out" 2>"$temp_dir/qpdf_err.log" || qpdf_rc=$?

    # qpdf exit codes: 0=success, 3=warnings (output still produced), others=error
    if [[ "$qpdf_rc" -ne 0 && "$qpdf_rc" -ne 3 ]] || [[ ! -f "$qpdf_out" ]] || [[ ! -s "$qpdf_out" ]]; then
        log_error "qpdf post-processing failed (exit code $qpdf_rc):"
        cat "$temp_dir/qpdf_err.log" >&2
        return "$EXIT_NORMALIZATION_FAILED"
    fi
    if [[ "$qpdf_rc" -eq 3 ]]; then
        log_warn "qpdf produced warnings (continuing):"
        log_verbose "$(cat "$temp_dir/qpdf_err.log")"
    fi

    cp "$qpdf_out" "$output_pdf"
    log_verbose "Normalization complete: $output_pdf"
    return "$EXIT_OK"
}

# Allow running this script directly for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 INPUT_PDF OUTPUT_PDF [letter|a4]"
        exit "$EXIT_USAGE"
    fi
    normalize_pdf "$1" "$2" "${3:-letter}"
fi
