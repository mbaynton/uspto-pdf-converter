# Test Files

Sample files used for end-to-end testing of the USPTO PDF Converter.

## File Inventory

| File | Format | Size | Purpose |
|------|--------|------|---------|
| sample.doc | Microsoft Word 97-2003 | 102 KB | Office document conversion |
| sample.docx | Microsoft Word 2007+ | 1.3 MB | Modern Office format |
| sample.xls | Microsoft Excel 97-2003 | 16 KB | Spreadsheet conversion |
| sample.xlsx | Microsoft Excel 2007+ | 29 KB | Modern Excel format |
| sample.ppt | Microsoft PowerPoint 97-2003 | 912 KB | Presentation conversion |
| sample.pptx | Microsoft PowerPoint 2007+ | 103 KB | Modern PowerPoint format |
| sample.odt | OpenDocument Text | 21 KB | Open format document |
| sample.ods | OpenDocument Spreadsheet | 19 KB | Open format spreadsheet |
| sample.odp | OpenDocument Presentation | 389 KB | Open format presentation |
| sample.rtf | Rich Text Format | 512 KB | Cross-platform document |
| sample.pdf | PDF 1.7 | 35 KB | PDF normalization test |
| sample.jpg | JPEG image | 2.4 KB | Image to PDF conversion |
| sample.png | PNG image | 27 KB | Image to PDF conversion |
| sample.tiff | TIFF image | 650 KB | High-resolution image |
| sample.bmp | BMP image | 818 KB | Bitmap image |
| sample.gif | GIF image | 1.0 MB | Animated/static image |
| sample.ps | PostScript | 404 KB | PostScript conversion |
| sample.eps | Encapsulated PostScript | 404 KB | EPS conversion |

**Total**: 18 files covering all supported input formats

## Sources

Test files were obtained from publicly available sources:

- **file-examples.com**: Most sample files (DOC, XLS, PPT, ODT, ODS, ODP, RTF, PDF, JPG, PNG, TIFF, GIF)
- **Public domain examples**: PS, EPS, BMP files from various open repositories
- **User-provided**: DOCX, XLSX, PPTX from local sample creation

All files are small (< 2 MB) to keep the repository lightweight and tests fast.

## Licensing

These files are used solely for testing purposes under fair use. They contain no copyrighted content and are either:
- Explicitly marked as examples/samples by their sources
- Generated synthetically for testing
- Simple documents with no creative content

If you are the copyright holder of any file here and would like it removed, please open an issue.

## Adding New Test Files

To add a new test file:

1. Ensure the file is small (preferably < 1 MB)
2. Ensure the file is freely redistributable
3. Add it to this directory with a descriptive name: `sample.<ext>`
4. Update this README with file information
5. Add a test to `test/conversion.bats`:
   ```bash
   @test "converts .EXT file successfully" {
       check_test_file_exists "sample.EXT"
       run convert_and_validate "$(get_test_file sample.EXT)" "ext-test"
       assert_success
   }
   ```
6. Run tests to verify: `./run-tests.sh`

## File Verification

To verify file integrity:

```bash
# Check file types
file test-files/*

# Check file sizes
ls -lh test-files/

# Count files
ls -1 test-files/ | wc -l
```

Expected output: 18 files of various types, all under 2 MB each.
