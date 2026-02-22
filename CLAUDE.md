# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A shell script-based tool that converts documents to USPTO Patent Center compliant PDFs. The project handles 10+ input formats (Office, images, text, LaTeX, HTML, PostScript, PDF) and validates the output against USPTO Patent Center requirements.

## Key Commands

### Convert documents to USPTO-compliant PDFs
```bash
./uspto-pdf-convert.sh [options] INPUT_FILE [INPUT_FILE ...]

# Options:
#   -o DIR      Output directory (default: current directory)
#   -p SIZE     Page size: letter or a4 (default: letter)
#   -n          Skip post-conversion validation
#   -v          Verbose output
#   -h          Show help
```

### Validate PDFs against USPTO requirements
```bash
./uspto-pdf-validate.sh [-v] PDF_FILE [PDF_FILE ...]
```

### Install all dependencies
```bash
sudo ./install-deps.sh
```

### Run with Docker
```bash
# Build the image
docker build -t uspto-pdf-converter .

# Convert a file
docker run --rm -v "$(pwd):/work" uspto-pdf-converter input.docx

# Validate a PDF
docker run --rm -v "$(pwd):/work" --entrypoint uspto-pdf-validate.sh uspto-pdf-converter input.pdf
```

## Architecture

### Three-Stage Conversion Pipeline

1. **Format-Specific Conversion** ([lib/convert-*.sh](lib/))
   - Each format has a dedicated converter that produces a raw PDF
   - Converters: `convert-office.sh`, `convert-image.sh`, `convert-text.sh`, `convert-html.sh`, `convert-latex.sh`, `convert-postscript.sh`
   - Called from [uspto-pdf-convert.sh:109-131](uspto-pdf-convert.sh#L109-L131) via case statement

2. **Normalization** ([lib/normalize.sh](lib/normalize.sh))
   - Converts any PDF to USPTO-compliant format
   - Uses `pdftocairo` for page size normalization, font re-embedding, and layer flattening
   - Uses `qpdf` for version downgrade (≤1.6), annotation flattening, and attachment removal
   - Handles landscape→portrait rotation automatically

3. **Validation** ([uspto-pdf-validate.sh](uspto-pdf-validate.sh))
   - Runs 9 compliance checks:
     - PDF version ≤ 1.6
     - Page size (US Letter or A4 portrait only)
     - All fonts embedded
     - No encryption
     - Image resolution ≥ 300 DPI
     - No OCG layers
     - No file attachments
     - No JavaScript
     - No multimedia/3D content

### Code Organization

```
.
├── uspto-pdf-convert.sh          # Main conversion entry point
├── uspto-pdf-validate.sh         # Validation entry point
├── install-deps.sh               # Dependency installer
├── Dockerfile                    # Containerized environment
└── lib/                          # Shared library modules
    ├── common.sh                 # Logging, exit codes, format detection, temp dir management
    ├── normalize.sh              # USPTO normalization pipeline (pdftocairo + qpdf)
    ├── convert-office.sh         # LibreOffice conversions
    ├── convert-image.sh          # Image conversions (img2pdf + ImageMagick)
    ├── convert-text.sh           # Text/Markdown conversions (pandoc)
    ├── convert-html.sh           # HTML conversions (Chrome headless)
    ├── convert-latex.sh          # LaTeX conversions (pdflatex)
    └── convert-postscript.sh     # PostScript conversions (Ghostscript)
```

### Shared Utilities ([lib/common.sh](lib/common.sh))

All scripts source `common.sh` which provides:
- **Exit codes**: `EXIT_OK`, `EXIT_CONVERSION_FAILED`, `EXIT_VALIDATION_FAILED`, etc.
- **Logging functions**: `log_info`, `log_error`, `log_warn`, `log_verbose`, `log_pass`, `log_fail`
- **Tool checking**: `require_tool COMMAND PACKAGE` - checks for dependencies
- **Temp directory management**: `make_temp_dir` with automatic cleanup on exit
- **Format detection**: `detect_format FILE` - identifies file type by extension or MIME type

### Design Patterns

1. **Sourceable Modules**: All lib/ scripts can be sourced or run standalone for testing
   - Each provides a main function (e.g., `convert_office INPUT OUTPUT`)
   - Bottom of each script has: `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then ... fi`

2. **Temporary File Safety**: All conversions use temp directories that are automatically cleaned up on exit via trap

3. **Graceful Degradation**: When optional tools are missing, scripts warn but continue (e.g., validation skips certain checks if qpdf unavailable)

4. **Multiple File Processing**: Both main scripts handle multiple input files and provide summary statistics

5. **Strict Error Handling**: Scripts use `set -euo pipefail` and check return codes explicitly

## Testing Strategy

Test individual converters by running them directly:
```bash
# Test Office converter
./lib/convert-office.sh test.docx /tmp/output.pdf

# Test normalization
./lib/normalize.sh input.pdf /tmp/normalized.pdf letter

# Test full pipeline
./uspto-pdf-convert.sh -v test.docx
./uspto-pdf-validate.sh test.pdf
```

## Critical USPTO Requirements

When modifying the normalization or validation logic, remember these critical constraints:

1. **PDF version must be ≤ 1.6** - enforced in [normalize.sh:102](lib/normalize.sh#L102) via `qpdf --force-version=1.6`
2. **Portrait pages only** - landscape pages are rotated in [normalize.sh:37-79](lib/normalize.sh#L37-L79)
3. **Font embedding required** - achieved via `pdftocairo` which re-embeds all fonts including Base 14 substitutes
4. **Page size tolerance** - 5-point tolerance for Letter (612×792) and A4 (595×842) in [validate.sh:34](uspto-pdf-validate.sh#L34)
5. **No layers** - flattened by `pdftocairo` and checked in [validate.sh:256-275](uspto-pdf-validate.sh#L256-L275)
6. **File size must be ≤ 25 MiB** - enforced in [split.sh](lib/split.sh) by automatically splitting large PDFs into multiple parts with 24.5 MiB safety margin. Files are split on page boundaries and named with `_partN.pdf` suffix

## Dependencies

Core tools (required for all operations):
- `qpdf` - PDF manipulation
- `poppler-utils` - PDF processing (pdftocairo, pdfinfo, pdffonts, pdfimages)
- `file` - format detection
- `binutils` - strings command for validation
- `coreutils` - includes `numfmt` for human-readable file size display, `stat` for file size checking

Format-specific tools:
- **Office**: `libreoffice` (headless mode)
- **Images**: `imagemagick`, `img2pdf` (Python package)
- **Text/Markdown**: `pandoc`, `texlive`
- **HTML**: `google-chrome-stable` or `chromium`
- **LaTeX**: `pdflatex`, texlive packages
- **PostScript**: `ghostscript`
