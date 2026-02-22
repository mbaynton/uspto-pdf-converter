# helpers.bash - Common test helper functions for bats tests

# Get the project root directory
get_project_root() {
    echo "$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

# Setup test environment
setup_test_env() {
    # Create temporary output directory for this test
    export TEST_OUTPUT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/uspto-test-XXXXXX")

    # Get project root and add scripts to PATH
    export PROJECT_ROOT=$(get_project_root)
    export PATH="${PROJECT_ROOT}:${PATH}"

    # Track test start time (for cleanup)
    export TEST_START_TIME=$(date +%s)
}

# Teardown test environment
teardown_test_env() {
    # Clean up temporary output directory if it exists
    if [[ -n "${TEST_OUTPUT_DIR}" ]] && [[ -d "${TEST_OUTPUT_DIR}" ]]; then
        rm -rf "${TEST_OUTPUT_DIR}"
    fi
}

# Get path to a test file
# Usage: get_test_file "sample.docx"
get_test_file() {
    local filename="$1"
    echo "${PROJECT_ROOT}/test-files/${filename}"
}

# Get expected output filename for an input file
# Usage: get_output_filename "sample.docx"
get_output_filename() {
    local input_file="$1"
    local basename=$(basename "$input_file")
    local name_no_ext="${basename%.*}"
    echo "${TEST_OUTPUT_DIR}/${name_no_ext}.pdf"
}

# Run converter on a file
# Returns 0 if conversion succeeds, non-zero otherwise
# Usage: run_converter "input.docx" "output.pdf"
run_converter() {
    local input_file="$1"
    local output_file="$2"

    local output_dir=$(dirname "$output_file")

    # Run the converter
    "${PROJECT_ROOT}/uspto-pdf-convert.sh" \
        -o "$output_dir" \
        -n \
        "$input_file" >&2

    # Check if output file was created
    if [[ -f "$output_file" ]]; then
        return 0
    else
        # Check for split files (multiple parts)
        local basename=$(basename "$output_file" .pdf)
        local output_dir=$(dirname "$output_file")
        if ls "${output_dir}/${basename}"_part*.pdf >/dev/null 2>&1; then
            return 0  # Split files exist, that's OK
        fi
        return 1
    fi
}

# Run validator on a PDF file
# Returns 0 if validation passes, non-zero otherwise
# Usage: run_validator "output.pdf"
run_validator() {
    local pdf_file="$1"

    "${PROJECT_ROOT}/uspto-pdf-validate.sh" "$pdf_file" >&2
    return $?
}

# Convert a file and validate the output
# This is the main test function used by most tests
# Usage: convert_and_validate "sample.docx" "docx-test"
convert_and_validate() {
    local input_file="$1"
    local test_name="${2:-test}"

    # Derive output filename
    local basename=$(basename "$input_file")
    local name_no_ext="${basename%.*}"
    local output_file="${TEST_OUTPUT_DIR}/${name_no_ext}.pdf"

    # Run conversion
    echo "Converting: $input_file" >&2
    if ! run_converter "$input_file" "$output_file"; then
        echo "ERROR: Conversion failed for $input_file" >&2
        return 1
    fi

    # Check if we have split files
    local pdf_files=()
    if [[ -f "$output_file" ]]; then
        pdf_files=("$output_file")
    else
        # Look for split files
        local pattern="${TEST_OUTPUT_DIR}/${name_no_ext}"
        if ls "${pattern}"_part*.pdf >/dev/null 2>&1; then
            mapfile -t pdf_files < <(ls "${pattern}"_part*.pdf | sort)
        else
            echo "ERROR: No output files found for $input_file" >&2
            return 1
        fi
    fi

    # Validate each output file
    echo "Validating ${#pdf_files[@]} output file(s)" >&2
    for pdf_file in "${pdf_files[@]}"; do
        echo "  Validating: $(basename "$pdf_file")" >&2
        if ! run_validator "$pdf_file"; then
            echo "ERROR: Validation failed for $(basename "$pdf_file")" >&2
            return 1
        fi
    done

    echo "SUCCESS: Converted and validated $input_file" >&2
    return 0
}

# Count output files matching a pattern
# Usage: count_output_files "*.pdf"
count_output_files() {
    local pattern="$1"
    local count=$(ls -1 "${TEST_OUTPUT_DIR}/"${pattern} 2>/dev/null | wc -l)
    echo "$count"
}

# Check if converter script exists and is executable
check_converter_exists() {
    if [[ ! -x "${PROJECT_ROOT}/uspto-pdf-convert.sh" ]]; then
        echo "ERROR: uspto-pdf-convert.sh not found or not executable" >&2
        return 1
    fi
    return 0
}

# Check if validator script exists and is executable
check_validator_exists() {
    if [[ ! -x "${PROJECT_ROOT}/uspto-pdf-validate.sh" ]]; then
        echo "ERROR: uspto-pdf-validate.sh not found or not executable" >&2
        return 1
    fi
    return 0
}

# Check if a test file exists
check_test_file_exists() {
    local filename="$1"
    local filepath=$(get_test_file "$filename")
    if [[ ! -f "$filepath" ]]; then
        skip "Test file not found: $filename"
    fi
}
