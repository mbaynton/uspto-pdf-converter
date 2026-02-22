#!/usr/bin/env bats
# conversion.bats - End-to-end conversion tests for all supported formats

load test_helper/bats-support/load
load test_helper/bats-assert/load
load helpers

setup() {
    setup_test_env
    check_converter_exists || skip
    check_validator_exists || skip
}

teardown() {
    teardown_test_env
}

# Office Documents - Microsoft Office

@test "converts .doc (Word 97-2003) file successfully" {
    check_test_file_exists "sample.doc"
    run convert_and_validate "$(get_test_file sample.doc)" "doc-test"
    assert_success
}

@test "converts .docx (Word 2007+) file successfully" {
    check_test_file_exists "sample.docx"
    run convert_and_validate "$(get_test_file sample.docx)" "docx-test"
    assert_success
}

@test "converts .xls (Excel 97-2003) file successfully" {
    check_test_file_exists "sample.xls"
    run convert_and_validate "$(get_test_file sample.xls)" "xls-test"
    assert_success
}

@test "converts .xlsx (Excel 2007+) file successfully" {
    check_test_file_exists "sample.xlsx"
    run convert_and_validate "$(get_test_file sample.xlsx)" "xlsx-test"
    assert_success
}

@test "converts .ppt (PowerPoint 97-2003) file successfully" {
    check_test_file_exists "sample.ppt"
    run convert_and_validate "$(get_test_file sample.ppt)" "ppt-test"
    assert_success
}

@test "converts .pptx (PowerPoint 2007+) file successfully" {
    check_test_file_exists "sample.pptx"
    run convert_and_validate "$(get_test_file sample.pptx)" "pptx-test"
    assert_success
}

# Office Documents - OpenDocument Format

@test "converts .odt (OpenDocument Text) file successfully" {
    check_test_file_exists "sample.odt"
    run convert_and_validate "$(get_test_file sample.odt)" "odt-test"
    assert_success
}

@test "converts .ods (OpenDocument Spreadsheet) file successfully" {
    check_test_file_exists "sample.ods"
    run convert_and_validate "$(get_test_file sample.ods)" "ods-test"
    assert_success
}

@test "converts .odp (OpenDocument Presentation) file successfully" {
    check_test_file_exists "sample.odp"
    run convert_and_validate "$(get_test_file sample.odp)" "odp-test"
    assert_success
}

# Other Document Formats

@test "converts .rtf (Rich Text Format) file successfully" {
    check_test_file_exists "sample.rtf"
    run convert_and_validate "$(get_test_file sample.rtf)" "rtf-test"
    assert_success
}

@test "normalizes existing .pdf file successfully" {
    check_test_file_exists "sample.pdf"
    run convert_and_validate "$(get_test_file sample.pdf)" "pdf-test"
    assert_success
}

# Image Formats

@test "converts .jpg image file successfully" {
    check_test_file_exists "sample.jpg"
    run convert_and_validate "$(get_test_file sample.jpg)" "jpg-test"
    assert_success
}

@test "converts .png image file successfully" {
    check_test_file_exists "sample.png"
    run convert_and_validate "$(get_test_file sample.png)" "png-test"
    assert_success
}

@test "converts .tiff image file successfully" {
    check_test_file_exists "sample.tiff"
    run convert_and_validate "$(get_test_file sample.tiff)" "tiff-test"
    assert_success
}

@test "converts .bmp image file successfully" {
    check_test_file_exists "sample.bmp"
    run convert_and_validate "$(get_test_file sample.bmp)" "bmp-test"
    assert_success
}

@test "converts .gif image file successfully" {
    check_test_file_exists "sample.gif"
    run convert_and_validate "$(get_test_file sample.gif)" "gif-test"
    assert_success
}

# PostScript Formats

@test "converts .ps (PostScript) file successfully" {
    check_test_file_exists "sample.ps"
    run convert_and_validate "$(get_test_file sample.ps)" "ps-test"
    assert_success
}

@test "converts .eps (Encapsulated PostScript) file successfully" {
    check_test_file_exists "sample.eps"
    run convert_and_validate "$(get_test_file sample.eps)" "eps-test"
    assert_success
}
