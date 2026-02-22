#!/bin/bash
# uspto-pdf-validate.sh — Validate a PDF against USPTO Patent Center requirements
#
# Usage:
#   uspto-pdf-validate.sh [-v] PDF_FILE [PDF_FILE ...]
#
# Checks:
#   1. PDF version <= 1.6
#   2. Page size is US Letter or A4 (within tolerance)
#   3. All fonts are embedded
#   4. No encryption / password protection
#   5. Image resolution >= 300 DPI
#   6. No OCG layers
#   7. No file attachments
#   8. No JavaScript
#   9. No multimedia / 3D content
#
# Exit codes:
#   0 = all checks passed
#   5 = one or more checks failed
#   2 = required tool missing
#   6 = usage error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Page size constants (in points) with tolerance
readonly LETTER_W=612
readonly LETTER_H=792
readonly A4_W=595
readonly A4_H=842
readonly SIZE_TOLERANCE=5  # points

# Track overall result
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0

record_pass() {
    log_pass "$1"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

record_fail() {
    log_fail "$1"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
}

record_warn() {
    echo -e "  ${YELLOW}WARN${RESET}: $1"
    CHECKS_WARNED=$((CHECKS_WARNED + 1))
}

# Helper: run pdfinfo and strip any null bytes from output (Ghostscript
# sometimes embeds null bytes in metadata fields, causing grep to treat
# the stream as binary).
safe_pdfinfo() {
    pdfinfo "$@" 2>/dev/null | tr -d '\0'
}

# --- Check functions ---

check_pdf_version() {
    local pdf_file="$1"
    local version
    version=$(safe_pdfinfo "$pdf_file" | grep "^PDF version:" | awk '{print $3}')

    if [[ -z "$version" ]]; then
        record_fail "PDF version: could not determine"
        return
    fi

    # Compare as float: version <= 1.6
    if awk "BEGIN {exit !($version <= 1.6)}"; then
        record_pass "PDF version: $version (<= 1.6)"
    else
        record_fail "PDF version: $version (must be <= 1.6)"
    fi
}

check_page_size() {
    local pdf_file="$1"

    local page_count
    page_count=$(safe_pdfinfo "$pdf_file" | grep "^Pages:" | awk '{print $2}')
    page_count="${page_count:-0}"

    if [[ "$page_count" -eq 0 ]]; then
        record_fail "Page size: could not determine page count"
        return
    fi

    # Check every page in a single pdfinfo + awk pass.
    # Portrait only — USPTO rejects landscape pages.
    local result
    result=$(pdfinfo -f 1 -l "$page_count" "$pdf_file" 2>/dev/null | tr -d '\0' | awk -v \
        tol="$SIZE_TOLERANCE" -v lw="$LETTER_W" -v lh="$LETTER_H" -v aw="$A4_W" -v ah="$A4_H" '
        /^Page[[:space:]]+[0-9]+[[:space:]]+size:/ {
            page = $2; w = $4; h = $6
            total++

            dw_l = w - lw; if (dw_l < 0) dw_l = -dw_l
            dh_l = h - lh; if (dh_l < 0) dh_l = -dh_l
            is_letter = (dw_l <= tol && dh_l <= tol)

            dw_a = w - aw; if (dw_a < 0) dw_a = -dw_a
            dh_a = h - ah; if (dh_a < 0) dh_a = -dh_a
            is_a4 = (dw_a <= tol && dh_a <= tol)

            if (!is_letter && !is_a4) {
                bad++
                if (bad <= 5) bad_list = bad_list (bad_list ? ", " : "") \
                    "p" page "(" w "x" h ")"
            }
        }
        END {
            if (total == 0) { print "error 0 0"; exit }
            printf "%d %d %d %s\n", total, bad, (bad > 5 ? bad - 5 : 0), bad_list
        }
    ')

    local total bad more bad_list
    total=$(echo "$result" | awk '{print $1}')
    bad=$(echo "$result" | awk '{print $2}')
    more=$(echo "$result" | awk '{print $3}')
    bad_list=$(echo "$result" | cut -d' ' -f4-)

    if [[ "$total" == "error" ]]; then
        record_fail "Page size: could not determine"
        return
    fi

    if [[ "$bad" -eq 0 ]]; then
        record_pass "Page size: all $total pages are US Letter or A4 (portrait)"
    else
        local detail="$bad_list"
        [[ "$more" -gt 0 ]] && detail="$detail, +$more more"
        record_fail "Page size: $bad of $total pages non-compliant: $detail"
    fi
}

check_fonts_embedded() {
    local pdf_file="$1"

    local fonts_output
    fonts_output=$(pdffonts "$pdf_file" 2>/dev/null)

    local font_lines
    font_lines=$(echo "$fonts_output" | tail -n +3)

    if [[ -z "$font_lines" ]]; then
        record_pass "Fonts: no fonts in document (image-only PDF or no text)"
        return
    fi

    local total=0
    local not_embedded=0
    local not_embedded_names=""

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        total=$((total + 1))

        # pdffonts columns end with: emb sub uni object ID
        # The emb/sub/uni fields are each "yes" or "no", followed by the
        # numeric object ID. Parse from the right using a regex.
        # Match: (yes|no) \s+ (yes|no) \s+ (yes|no) \s+ digits \s+ digits \s*$
        local emb
        if [[ "$line" =~ (yes|no)[[:space:]]+(yes|no)[[:space:]]+(yes|no)[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]*$ ]]; then
            emb="${BASH_REMATCH[1]}"
        else
            # Fallback: can't parse this line, assume embedded
            emb="yes"
        fi

        if [[ "$emb" != "yes" ]]; then
            not_embedded=$((not_embedded + 1))
            local font_name
            font_name=$(echo "$line" | awk '{print $1}')
            not_embedded_names+="  - $font_name"$'\n'
        fi
    done <<< "$font_lines"

    if [[ "$not_embedded" -eq 0 ]]; then
        record_pass "Fonts: all $total fonts embedded"
    else
        record_fail "Fonts: $not_embedded of $total fonts NOT embedded:"
        echo "$not_embedded_names" >&2
    fi
}

check_encryption() {
    local pdf_file="$1"

    local encrypted
    encrypted=$(safe_pdfinfo "$pdf_file" | grep "^Encrypted:" | awk '{print $2}')

    if [[ "$encrypted" == "no" ]]; then
        record_pass "Encryption: none"
    elif [[ -z "$encrypted" ]]; then
        record_warn "Encryption: could not determine (assuming none)"
    else
        record_fail "Encryption: document is encrypted (prohibited)"
    fi
}

check_image_resolution() {
    local pdf_file="$1"

    if ! command -v pdfimages &>/dev/null; then
        record_warn "Image resolution: pdfimages not available, skipping"
        return
    fi

    # Use awk to process pdfimages output in a single pass (avoids slow
    # bash loops on PDFs with thousands of images).
    local result
    result=$(pdfimages -list "$pdf_file" 2>/dev/null | awk '
        NR <= 2 { next }  # skip header and dashes lines
        {
            total++
            x = $13; y = $14
            # Skip non-numeric DPI values
            if (x !~ /^[0-9]+$/ || y !~ /^[0-9]+$/) next
            lower = (y < x) ? y : x
            if (lower < min_dpi || min_dpi == 0) min_dpi = lower
            if (lower < 300) low_res++
        }
        END {
            if (total == 0) { print "none"; exit }
            printf "%d %d %d\n", total, low_res, min_dpi
        }
    ')

    if [[ "$result" == "none" ]]; then
        record_pass "Image resolution: no raster images in document"
        return
    fi

    local total low_res min_dpi
    read -r total low_res min_dpi <<< "$result"

    if [[ "$low_res" -eq 0 ]]; then
        if [[ "$min_dpi" -gt 0 ]]; then
            record_pass "Image resolution: $total images, minimum ${min_dpi} DPI (>= 300)"
        else
            record_pass "Image resolution: $total images checked"
        fi
    else
        record_warn "Image resolution: $low_res of $total images below 300 DPI (minimum: ${min_dpi} DPI)"
    fi
}

check_layers() {
    local pdf_file="$1"

    if ! command -v qpdf &>/dev/null; then
        record_warn "Layers: qpdf not available, skipping OCG check"
        return
    fi

    # Check for Optional Content (OCG/layers) via qpdf JSON output
    local has_layers=0
    if qpdf --json "$pdf_file" 2>/dev/null | grep -q '"OCProperties"'; then
        has_layers=1
    fi

    if [[ "$has_layers" -eq 0 ]]; then
        record_pass "Layers: none detected"
    else
        record_fail "Layers: OCG/Optional Content detected (must be flattened)"
    fi
}

check_attachments() {
    local pdf_file="$1"

    if ! command -v qpdf &>/dev/null; then
        record_warn "Attachments: qpdf not available, skipping"
        return
    fi

    local attachments
    attachments=$(qpdf --list-attachments "$pdf_file" 2>/dev/null)

    # qpdf prints "FILE has no embedded files" when there are none
    if [[ -z "$attachments" ]] || echo "$attachments" | grep -q "no embedded files"; then
        record_pass "Attachments: none"
    else
        record_fail "Attachments: file attachments detected (prohibited)"
    fi
}

check_javascript() {
    local pdf_file="$1"

    # Use pdfinfo's built-in JavaScript detection if available
    local js_field
    js_field=$(safe_pdfinfo "$pdf_file" | grep "^JavaScript:" | awk '{print $2}')

    if [[ "$js_field" == "yes" ]]; then
        record_fail "JavaScript: JavaScript content detected (prohibited)"
        return
    fi

    # Fallback: search raw PDF for JavaScript action references
    local has_js=0
    if strings "$pdf_file" 2>/dev/null | grep -aqiE '/JavaScript|/S\s*/JavaScript'; then
        has_js=1
    fi

    if [[ "$has_js" -eq 0 ]]; then
        record_pass "JavaScript: none detected"
    else
        record_fail "JavaScript: JavaScript content detected (prohibited)"
    fi
}

check_multimedia() {
    local pdf_file="$1"

    local issues=""
    local pdf_strings
    pdf_strings=$(strings "$pdf_file" 2>/dev/null)

    # Use word-boundary-aware patterns to avoid false positives from
    # hex values or font names containing these substrings.
    # PDF operators are always /Name at the start of a token.
    if echo "$pdf_strings" | grep -aqP '(?<![:\w])/Movie(?!\w)'; then
        issues+="Movie "
    fi
    if echo "$pdf_strings" | grep -aqP '(?<![:\w])/Sound(?!\w)'; then
        issues+="Sound "
    fi
    if echo "$pdf_strings" | grep -aqP '(?<![:\w])/3D(?![0-9a-zA-Z])'; then
        issues+="3D "
    fi
    if echo "$pdf_strings" | grep -aqP '(?<![:\w])/RichMedia(?!\w)'; then
        issues+="RichMedia "
    fi

    if [[ -z "$issues" ]]; then
        record_pass "Multimedia/3D: none detected"
    else
        record_fail "Multimedia/3D: prohibited content detected: $issues"
    fi
}

# --- Main validation ---

validate_pdf() {
    local pdf_file="$1"

    CHECKS_PASSED=0
    CHECKS_FAILED=0
    CHECKS_WARNED=0

    echo ""
    echo -e "${BOLD}USPTO EFS-Web PDF Validation: $(basename "$pdf_file")${RESET}"
    echo "────────────────────────────────────────────────────"

    check_pdf_version "$pdf_file"
    check_page_size "$pdf_file"
    check_fonts_embedded "$pdf_file"
    check_encryption "$pdf_file"
    check_image_resolution "$pdf_file"
    check_layers "$pdf_file"
    check_attachments "$pdf_file"
    check_javascript "$pdf_file"
    check_multimedia "$pdf_file"

    echo "────────────────────────────────────────────────────"
    local total=$((CHECKS_PASSED + CHECKS_FAILED))
    local warn_suffix=""
    [[ "$CHECKS_WARNED" -gt 0 ]] && warn_suffix=", $CHECKS_WARNED warnings"

    if [[ "$CHECKS_FAILED" -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}VALIDATION PASSED${RESET} ($CHECKS_PASSED/$total checks passed${warn_suffix})"
        return 0
    else
        echo -e "${RED}${BOLD}VALIDATION FAILED${RESET} ($CHECKS_FAILED/$total checks failed, $CHECKS_PASSED passed${warn_suffix})"
        return 1
    fi
}

# --- Entry point ---

main() {
    local files=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v)
                VERBOSE=1
                export VERBOSE
                shift
                ;;
            -h|--help)
                cat <<'EOF'
Usage: uspto-pdf-validate.sh [-v] PDF_FILE [PDF_FILE ...]

Validate PDFs against USPTO EFS-Web requirements.

Options:
  -v    Verbose output
  -h    Show help

Exit codes:
  0     All checks passed
  5     One or more checks failed
  2     Required tool missing
  6     Usage error
EOF
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                exit "$EXIT_USAGE"
                ;;
            *)
                files+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#files[@]} -eq 0 ]]; then
        log_error "No PDF files specified."
        echo "Usage: $0 [-v] PDF_FILE [PDF_FILE ...]"
        exit "$EXIT_USAGE"
    fi

    # Check required tools
    require_tool pdfinfo poppler-utils || exit $?
    require_tool pdffonts poppler-utils || exit $?
    require_tool strings binutils || exit $?

    local any_failed=0

    for pdf_file in "${files[@]}"; do
        if [[ ! -f "$pdf_file" ]]; then
            log_error "File not found: $pdf_file"
            any_failed=1
            continue
        fi

        if ! validate_pdf "$pdf_file"; then
            any_failed=1
        fi
    done

    if [[ "$any_failed" -ne 0 ]]; then
        exit "$EXIT_VALIDATION_FAILED"
    fi
    exit "$EXIT_OK"
}

main "$@"
