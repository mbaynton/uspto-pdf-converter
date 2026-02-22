# Test Suite

End-to-end tests for the USPTO PDF Converter using [Bats](https://github.com/bats-core/bats-core).

## Running Tests Locally

### Quick Start

```bash
# Run all tests
./run-tests.sh

# Run specific test file
test/bats/bin/bats test/conversion.bats

# Run tests matching a pattern
test/bats/bin/bats test/conversion.bats --filter "docx"
```

### First Time Setup

The test suite uses Git submodules for the Bats testing framework. On first run, `run-tests.sh` will automatically initialize these submodules. Alternatively, you can initialize them manually:

```bash
git submodule update --init --recursive
```

## Test Structure

### Test Files

- **`conversion.bats`**: Main conversion tests for all supported formats (Office, images, PostScript, PDF)
- **`helpers.bash`**: Shared helper functions used across all tests

### Helper Functions

The `helpers.bash` file provides reusable functions to keep individual tests minimal:

- `setup_test_env()` - Creates temporary output directory for each test
- `teardown_test_env()` - Cleans up temporary files after each test
- `convert_and_validate()` - Converts a file and validates the output (main test function)
- `get_test_file()` - Returns path to a test file
- `run_converter()` - Runs the converter on a file
- `run_validator()` - Runs the validator on a PDF

### Writing New Tests

To add a new test, follow this minimal pattern:

```bash
@test "converts .FORMAT file successfully" {
    check_test_file_exists "sample.FORMAT"
    run convert_and_validate "$(get_test_file sample.FORMAT)" "format-test"
    assert_success
}
```

That's it! The helper functions handle all the complexity of:
- Creating temporary directories
- Running the converter with correct options
- Handling file splitting for large PDFs
- Validating output files
- Cleaning up after the test

## Test Execution

### Local Testing

Tests run with the tools installed on your local system. Install dependencies first:

```bash
# Ubuntu/Debian
sudo ./install-deps.sh

# macOS
./install-deps.sh

# Or use Docker
docker build -t uspto-pdf-converter .
```

### CI/CD Testing

Tests automatically run on GitHub Actions for every push and pull request on these platforms:

- **Ubuntu** (latest) - Local installation via install-deps.sh
- **macOS** (latest) - Local installation via Homebrew
- **Fedora** (latest, via Docker) - Local installation via dnf
- **Docker** - Docker image build and basic conversion test

See [`.github/workflows/test.yml`](../.github/workflows/test.yml) for the complete CI configuration.

## Test Files

Test input files are located in [`test-files/`](../test-files/). See that directory's README for sources and licensing information.

Currently includes sample files for:
- Office formats: .doc, .docx, .xls, .xlsx, .ppt, .pptx, .odt, .ods, .odp, .rtf
- Images: .jpg, .png, .tiff, .bmp, .gif
- PostScript: .ps, .eps
- PDF: .pdf (for normalization testing)

## Debugging Failed Tests

### Verbose Output

Run tests with verbose output to see detailed conversion logs:

```bash
test/bats/bin/bats test/conversion.bats --tap
```

### Keep Test Outputs

Modify the `teardown()` function in your test to comment out cleanup:

```bash
teardown() {
    # teardown_test_env  # Comment this to keep test outputs
    echo "Test output dir: $TEST_OUTPUT_DIR"
}
```

### Run Single Test

Focus on a failing test:

```bash
test/bats/bin/bats test/conversion.bats --filter "exact test name"
```

### Check Tool Availability

Verify required tools are installed:

```bash
# Check core tools
which qpdf pdftocairo pdfinfo

# Check format-specific tools
which libreoffice convert pandoc gs chromium-browser
```

## Performance

- **Total tests**: ~18 conversion tests
- **Execution time**: 3-6 minutes (Office formats are slowest)
- **Parallel execution**: Not currently enabled (may cause file conflicts)

## Contributing

When adding support for a new file format:

1. Add a sample file to `test-files/`
2. Add a 3-line test to `conversion.bats`
3. Run `./run-tests.sh` to verify
4. Commit both the test and sample file

The CI will automatically test the new format on all platforms.
