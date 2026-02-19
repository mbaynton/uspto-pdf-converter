#!/bin/bash
# convert-image.sh — Convert image files to PDF
#
# Supported: .jpg, .jpeg, .png, .tiff, .tif, .bmp, .gif
#
# Strategy:
#   1. Use ImageMagick to check/fix DPI (ensure >= 300)
#   2. Use img2pdf for lossless embedding when possible (JPEG, PNG, TIFF)
#   3. Fall back to ImageMagick convert for formats img2pdf doesn't handle
#
# Usage (sourced): convert_image INPUT_FILE OUTPUT_PDF [PAGE_SIZE]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

convert_image() {
    local input_file="$1"
    local output_pdf="$2"
    local page_size="${3:-letter}"

    local temp_dir
    temp_dir=$(make_temp_dir)

    local ext="${input_file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    # Determine page dimensions in points
    local page_w page_h
    case "$page_size" in
        letter) page_w="8.5in"; page_h="11in" ;;
        a4)     page_w="210mm"; page_h="297mm" ;;
    esac

    # Try img2pdf first (lossless, no recompression)
    if command -v img2pdf &>/dev/null; then
        local img2pdf_input="$input_file"

        # img2pdf doesn't handle BMP or GIF — convert those to PNG first
        if [[ "$ext" == "bmp" || "$ext" == "gif" ]]; then
            require_tool convert imagemagick || return $?
            log_verbose "Converting $ext to PNG for img2pdf..."
            local png_tmp="$temp_dir/converted.png"
            if ! convert "$input_file" -density 300 "$png_tmp" 2>"$temp_dir/im_err.log"; then
                log_error "ImageMagick conversion to PNG failed:"
                cat "$temp_dir/im_err.log" >&2
                return "$EXIT_CONVERSION_FAILED"
            fi
            img2pdf_input="$png_tmp"
        fi

        log_verbose "Converting image with img2pdf: $input_file"
        local img2pdf_pagesize
        case "$page_size" in
            letter) img2pdf_pagesize="Letter" ;;
            a4)     img2pdf_pagesize="A4" ;;
        esac

        if img2pdf \
            --pagesize "$img2pdf_pagesize" \
            --auto-orient \
            --fit into \
            --output "$output_pdf" \
            "$img2pdf_input" 2>"$temp_dir/img2pdf_err.log"; then
            log_verbose "img2pdf conversion complete: $output_pdf"
            return "$EXIT_OK"
        fi

        log_warn "img2pdf failed, falling back to ImageMagick:"
        log_verbose "$(cat "$temp_dir/img2pdf_err.log")"
    fi

    # Fallback: ImageMagick convert
    require_tool convert imagemagick || return $?

    log_verbose "Converting image with ImageMagick: $input_file"

    # Get current DPI; default to 300 if not set
    local current_dpi
    current_dpi=$(identify -format "%x" "$input_file" 2>/dev/null | head -1)
    # identify returns values like "300 PixelsPerInch" or just a number
    current_dpi=$(echo "$current_dpi" | grep -oP '^\d+' || echo "0")

    local density_args=()
    if [[ -z "$current_dpi" || "$current_dpi" -lt 300 ]]; then
        # Image has no DPI metadata or low DPI — set to 300
        density_args=(-density 300 -units PixelsPerInch)
    fi

    if ! convert "$input_file" \
        "${density_args[@]}" \
        -compress None \
        -page "$page_size" \
        "$output_pdf" 2>"$temp_dir/im_err.log"; then
        log_error "ImageMagick conversion failed:"
        cat "$temp_dir/im_err.log" >&2
        return "$EXIT_CONVERSION_FAILED"
    fi

    log_verbose "ImageMagick conversion complete: $output_pdf"
    return "$EXIT_OK"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 INPUT_FILE OUTPUT_PDF [letter|a4]"
        exit "$EXIT_USAGE"
    fi
    convert_image "$1" "$2" "${3:-letter}"
fi
