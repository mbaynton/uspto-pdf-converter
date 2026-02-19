#!/bin/bash
# install-deps.sh — Install all dependencies for the USPTO PDF converter
#
# Run with: sudo ./install-deps.sh
#
# Supports: Debian/Ubuntu (apt), Fedora/RHEL (dnf), and macOS (brew)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

log_info()  { echo -e "${BOLD}[INFO]${RESET} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${RESET}   $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*"; }

detect_package_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v brew &>/dev/null; then
        echo "brew"
    else
        echo "unknown"
    fi
}

install_apt() {
    log_info "Updating package lists..."
    apt-get update -qq

    log_info "Installing system packages..."

    # -- Core (required for all conversions) --
    # qpdf: normalization pipeline (version downgrade, annotation flattening)
    # poppler-utils: normalization (pdftocairo) + validation (pdfinfo, pdffonts, pdfimages)
    # file: input format detection
    # binutils: validation (strings command for multimedia/JS detection)
    apt-get install -y \
        qpdf \
        poppler-utils \
        file \
        binutils

    # -- Format-specific (install only what you need) --

    # PostScript (.ps, .eps)
    apt-get install -y ghostscript

    # Images (.jpg, .jpeg, .png, .tiff, .tif, .bmp, .gif)
    apt-get install -y imagemagick python3-pip

    # Office (.doc, .docx, .xls, .xlsx, .ppt, .pptx, .odt, .ods, .odp, .rtf)
    apt-get install -y \
        libreoffice-writer \
        libreoffice-calc \
        libreoffice-impress

    # Markdown, plain text, RST (.md, .txt, .rst) and LaTeX (.tex)
    apt-get install -y \
        pandoc \
        texlive-latex-base \
        texlive-fonts-recommended \
        texlive-latex-extra

    # HTML (.html, .htm)
    apt-get install -y chromium-browser

    log_info "Installing Python packages..."
    # Images (.jpg, .jpeg, .png, .tiff, .tif, .bmp, .gif)
    pip3 install --break-system-packages img2pdf 2>/dev/null || \
        pip3 install img2pdf
}

install_dnf() {
    log_info "Installing system packages..."

    # -- Core (required for all conversions) --
    # qpdf: normalization pipeline (version downgrade, annotation flattening)
    # poppler-utils: normalization (pdftocairo) + validation (pdfinfo, pdffonts, pdfimages)
    # file: input format detection
    # binutils: validation (strings command for multimedia/JS detection)
    dnf install -y \
        qpdf \
        poppler-utils \
        file \
        binutils

    # -- Format-specific (install only what you need) --

    # PostScript (.ps, .eps)
    dnf install -y ghostscript

    # Images (.jpg, .jpeg, .png, .tiff, .tif, .bmp, .gif)
    dnf install -y ImageMagick python3-pip

    # Office (.doc, .docx, .xls, .xlsx, .ppt, .pptx, .odt, .ods, .odp, .rtf)
    dnf install -y \
        libreoffice-writer \
        libreoffice-calc \
        libreoffice-impress

    # Markdown, plain text, RST (.md, .txt, .rst) and LaTeX (.tex)
    dnf install -y \
        pandoc \
        texlive-scheme-basic \
        texlive-collection-fontsrecommended \
        texlive-collection-latexextra

    # HTML (.html, .htm)
    dnf install -y chromium

    log_info "Installing Python packages..."
    # Images (.jpg, .jpeg, .png, .tiff, .tif, .bmp, .gif)
    pip3 install img2pdf
}

install_brew() {
    log_info "Installing system packages..."

    # -- Core (required for all conversions) --
    # qpdf: normalization pipeline (version downgrade, annotation flattening)
    # poppler: normalization (pdftocairo) + validation (pdfinfo, pdffonts, pdfimages)
    brew install qpdf poppler

    # -- Format-specific (install only what you need) --

    # PostScript (.ps, .eps)
    brew install ghostscript

    # Images (.jpg, .jpeg, .png, .tiff, .tif, .bmp, .gif)
    brew install imagemagick img2pdf

    # Office (.doc, .docx, .xls, .xlsx, .ppt, .pptx, .odt, .ods, .odp, .rtf)
    brew install --cask libreoffice

    # Markdown, plain text, RST (.md, .txt, .rst) and LaTeX (.tex)
    brew install pandoc basictex

    # HTML (.html, .htm)
    brew install --cask chromium

    log_warn "On macOS, you may need to install additional LaTeX packages:"
    log_warn "  sudo tlmgr install collection-fontsrecommended collection-latexextra"
}

verify_tools() {
    echo ""
    log_info "Verifying installations..."
    local all_ok=1

    local tools=(
        # Core (all conversions)
        "qpdf:qpdf"
        "pdfinfo:poppler-utils"
        "pdffonts:poppler-utils"
        "pdfimages:poppler-utils"
        "pdftocairo:poppler-utils"
        "file:file"
        "strings:binutils"
        # PostScript (.ps, .eps)
        "gs:ghostscript"
        # Images (.jpg, .png, .tiff, .bmp, .gif)
        "convert:imagemagick"
        "img2pdf:img2pdf (pip)"
        # Office (.doc, .docx, .xls, .xlsx, .ppt, .pptx, .odt, .ods, .odp, .rtf)
        "libreoffice:libreoffice"
        # Markdown, text, RST (.md, .txt, .rst) and LaTeX (.tex)
        "pandoc:pandoc"
        "pdflatex:texlive"
    )

    for entry in "${tools[@]}"; do
        local tool="${entry%%:*}"
        local package="${entry##*:}"
        if command -v "$tool" &>/dev/null; then
            log_ok "$tool"
        else
            log_error "$tool (install: $package)"
            all_ok=0
        fi
    done

    # Chrome/Chromium — check multiple possible names
    local chrome_found=0
    for cmd in chromium-browser chromium google-chrome-stable google-chrome; do
        if command -v "$cmd" &>/dev/null; then
            log_ok "$cmd (browser for HTML conversion)"
            chrome_found=1
            break
        fi
    done
    if [[ "$chrome_found" -eq 0 ]]; then
        log_error "No Chrome/Chromium browser found (install: chromium-browser)"
        all_ok=0
    fi

    echo ""
    if [[ "$all_ok" -eq 1 ]]; then
        log_info "All dependencies installed successfully."
    else
        log_warn "Some dependencies are missing. See errors above."
    fi
}

main() {
    local pm
    pm=$(detect_package_manager)

    log_info "Detected package manager: $pm"

    case "$pm" in
        apt)  install_apt ;;
        dnf)  install_dnf ;;
        yum)
            log_warn "Using yum — attempting dnf-style install..."
            install_dnf
            ;;
        brew) install_brew ;;
        *)
            log_error "Unsupported package manager. Please install the following manually:"
            echo "  Core:        qpdf, poppler-utils (pdftocairo/pdfinfo/pdffonts/pdfimages), file, binutils"
            echo "  PostScript:  ghostscript"
            echo "  Images:      imagemagick, img2pdf (pip)"
            echo "  Office:      libreoffice"
            echo "  Text/LaTeX:  pandoc, texlive"
            echo "  HTML:        chromium or google-chrome"
            exit 1
            ;;
    esac

    verify_tools
}

main "$@"
