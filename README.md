# USPTO PDF Converter

Command-line scripts to automate conversion of documents to USPTO Patent Center compliant PDFs or validate a PDF against USPTO requirements.

## Features

### Document Conversion
Convert 10+ file formats to USPTO-compliant PDFs:
- **Office documents**: .doc, .docx, .xls, .xlsx, .ppt, .pptx, .odt, .ods, .odp, .rtf
- **Images**: .jpg, .jpeg, .png, .tiff, .tif, .bmp, .gif
- **Text formats**: .md, .markdown, .txt, .rst
- **Web formats**: .html, .htm
- **Scientific formats**: .tex, .latex
- **PostScript**: .ps, .eps
- **PDFs**: Re-normalizes existing PDFs for compliance

### Automatic Compliance
- **PDF version normalization**: Ensures PDF version ≤ 1.6
- **Page size standardization**: Converts to US Letter or A4 (portrait only)
- **Font embedding**: Embeds all fonts including Base 14 substitutes
- **Landscape rotation**: Automatically rotates landscape pages to portrait
- **Layer flattening**: Removes OCG/optional content layers
- **File size management**: Automatically splits PDFs exceeding 25 MiB into compliant parts
- **Content removal**: Strips encryption, JavaScript, multimedia, attachments

### Validation
Validates PDFs against all 9 USPTO Patent Center requirements:
1. PDF version ≤ 1.6
2. Page size (US Letter or A4, portrait only)
3. All fonts embedded
4. No encryption/password protection
5. Image resolution ≥ 300 DPI
6. No OCG layers
7. No file attachments
8. No JavaScript
9. No multimedia/3D content

## Installation

### Option 1: Docker (Recommended)

Pull the pre-built image from Docker Hub:

```bash
docker pull mbaynton/uspto-pdf-converter:latest
```

Create a convenient alias (optional):

```bash
# Add to your ~/.bashrc or ~/.zshrc
alias uspto-pdf-convert='docker run --rm -v "$(pwd):/work" mbaynton/uspto-pdf-converter'
alias uspto-pdf-validate='docker run --rm -v "$(pwd):/work" --entrypoint uspto-pdf-validate.sh mbaynton/uspto-pdf-converter'
```

### Option 2: Local Installation

For systems with `apt` (Debian/Ubuntu), `dnf` (Fedora/RHEL), or `brew` (macOS):

```bash
git clone https://github.com/yourusername/uspto-pdf-converter.git
cd uspto-pdf-converter
sudo ./install-deps.sh
```

**Note**: Local installation requires significant dependencies including LibreOffice, LaTeX, Chrome/Chromium, and various PDF processing tools.

## Usage

### Basic Conversion

Convert a document to USPTO-compliant PDF:

```bash
# Docker
docker run --rm -v "$(pwd):/work" mbaynton/uspto-pdf-converter document.docx

# Local
./uspto-pdf-convert.sh document.docx
```

Output will be created in the current directory as `document.pdf`.

### Advanced Options

```bash
uspto-pdf-convert.sh [options] INPUT_FILE [INPUT_FILE ...]

Options:
  -o DIR      Output directory (default: current directory)
  -p SIZE     Page size: letter or a4 (default: letter)
  -n          Skip post-conversion validation
  -v          Verbose output
  -h          Show help
```

**Examples:**

```bash
# Convert multiple files
docker run --rm -v "$(pwd):/work" mbaynton/uspto-pdf-converter file1.docx file2.png file3.html

# Output to specific directory with A4 page size
docker run --rm -v "$(pwd):/work" mbaynton/uspto-pdf-converter -o output -p a4 document.tex

# Verbose mode (useful for debugging)
docker run --rm -v "$(pwd):/work" mbaynton/uspto-pdf-converter -v large-file.pptx

# Skip validation (faster, not recommended)
docker run --rm -v "$(pwd):/work" mbaynton/uspto-pdf-converter -n document.pdf
```

### Large Files (Automatic Splitting)

Files exceeding 25 MiB are automatically split into multiple compliant parts:

```bash
docker run --rm -v "$(pwd):/work" mbaynton/uspto-pdf-converter large-presentation.pptx
```

Output:
```
large-presentation_part1.pdf  (24.2 MiB)
large-presentation_part2.pdf  (23.8 MiB)
large-presentation_part3.pdf  (15.1 MiB)
```

Each part is independently validated and ready for USPTO submission.

### PDF Validation Only

Validate existing PDFs without conversion:

```bash
# Docker
docker run --rm -v "$(pwd):/work" --entrypoint uspto-pdf-validate.sh \
  mbaynton/uspto-pdf-converter document.pdf

# Local
./uspto-pdf-validate.sh document.pdf
```

Validation output shows pass/fail for all 9 USPTO requirements.

## USPTO Patent Center Requirements

This tool enforces all USPTO EFS-Web PDF requirements:

| Requirement | Enforcement Method |
|-------------|-------------------|
| PDF version ≤ 1.6 | `qpdf --force-version=1.6` |
| US Letter or A4 portrait | `pdftocairo` with auto-rotation |
| All fonts embedded | `pdftocairo` re-embeds all fonts |
| No encryption | `qpdf --decrypt` if needed |
| Image resolution ≥ 300 DPI | Validated with `pdfimages` |
| No OCG layers | Flattened by `pdftocairo` |
| No attachments | Removed by `qpdf` |
| No JavaScript | Stripped during normalization |
| No multimedia/3D | Stripped during normalization |
| File size ≤ 25 MiB | Automatic page-boundary splitting |

## Technical Details

### Conversion Pipeline

Each file goes through a three-stage pipeline:

1. **Format-Specific Conversion**: Uses the appropriate tool (LibreOffice, Pandoc, Chrome, etc.) to create a raw PDF
2. **Normalization**: Uses `pdftocairo` and `qpdf` to enforce all USPTO requirements
3. **Validation**: Checks the output against all 9 compliance criteria

### Dependencies

Core tools (always required):
- `qpdf` - PDF manipulation
- `poppler-utils` - PDF processing (pdftocairo, pdfinfo, pdffonts, pdfimages)
- `file` - Format detection
- `binutils` - Validation (strings command)
- `coreutils` - File size checking (stat, numfmt)

Format-specific tools (optional, install only what you need):
- **Office**: LibreOffice
- **Images**: ImageMagick, img2pdf
- **Text/Markdown**: Pandoc, LaTeX
- **HTML**: Chrome or Chromium
- **LaTeX**: pdflatex, TeX Live
- **PostScript**: Ghostscript

## Building the Docker Image

To build the Docker image locally:

```bash
git clone https://github.com/yourusername/uspto-pdf-converter.git
cd uspto-pdf-converter
docker build -t uspto-pdf-converter .
```

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

## License

MIT

## Contributors

 * Mike Baynton (Developer)
 * Stacy Brooks (Paralegal)
 * Claude Code

## Acknowledgments

Built with:
- [qpdf](https://github.com/qpdf/qpdf) - PDF transformation
- [Poppler](https://poppler.freedesktop.org/) - PDF rendering and utilities
- [LibreOffice](https://www.libreoffice.org/) - Office document conversion
- [Pandoc](https://pandoc.org/) - Universal document converter
- [ImageMagick](https://imagemagick.org/) - Image processing
