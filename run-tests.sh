#!/bin/bash
# run-tests.sh - Run all bats tests for USPTO PDF Converter

set -e

cd "$(dirname "$0")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

echo "USPTO PDF Converter - Test Runner"
echo "=================================="
echo ""

# Check if bats is available
if [ ! -f "test/bats/bin/bats" ]; then
    echo -e "${YELLOW}Bats not found. Initializing git submodules...${RESET}"
    if ! git submodule update --init --recursive; then
        echo -e "${RED}ERROR: Failed to initialize git submodules${RESET}"
        echo "Please run: git submodule update --init --recursive"
        exit 1
    fi
    echo -e "${GREEN}Submodules initialized successfully${RESET}"
    echo ""
fi

# Check if test files exist
if [ ! -d "test-files" ] || [ -z "$(ls -A test-files 2>/dev/null)" ]; then
    echo -e "${YELLOW}WARNING: test-files directory is empty${RESET}"
    echo "Some tests may be skipped"
    echo ""
fi

# Run tests
echo "Running tests..."
echo ""

if test/bats/bin/bats test/*.bats "$@"; then
    echo ""
    echo -e "${GREEN}All tests passed!${RESET}"
    exit 0
else
    exit_code=$?
    echo ""
    echo -e "${RED}Some tests failed (exit code: $exit_code)${RESET}"
    exit $exit_code
fi
