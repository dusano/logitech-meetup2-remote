#!/bin/bash
# run_conformance_tests_swift.sh — run conformance tests against a generated Swift (SPM) build folder.
# Variant: install-inline (no prepare_environment script exists in this project).
#
# Usage: run_conformance_tests_swift.sh <build-folder> <conformance-tests-folder>
#
# Exit codes:
#   69 — unrecoverable: missing argument, missing toolchain, can't enter working folder
#   1  — no tests discovered
#   *  — otherwise, the exit code of `swift test` is propagated

echo "===== [1/8] Toolchain check ====="
if ! command -v swift >/dev/null 2>&1; then
    printf "Error: swift toolchain is not installed or not on PATH.\n" >&2
    exit 69
fi
echo "swift resolved at: $(command -v swift)"
swift --version

echo "===== [2/8] Argument validation ====="
if [ -z "$1" ] || [ -z "$2" ]; then
    printf "Usage: %s <build-folder> <conformance-tests-folder>\n" "$0" >&2
    exit 69
fi
BUILD_FOLDER="$1"
if [ ! -d "$BUILD_FOLDER" ]; then
    printf "Error: build folder '%s' does not exist or is not a directory.\n" "$BUILD_FOLDER" >&2
    exit 69
fi
echo "Build folder (read-only): $BUILD_FOLDER"

echo "===== [3/8] Resolve conformance tests folder ====="
case "$2" in
    /*) CONFORMANCE_TESTS_FOLDER="$2" ;;
    *)  CONFORMANCE_TESTS_FOLDER="$(pwd)/$2" ;;
esac
if [ ! -d "$CONFORMANCE_TESTS_FOLDER" ]; then
    printf "Error: conformance tests folder '%s' does not exist or is not a directory.\n" "$CONFORMANCE_TESTS_FOLDER" >&2
    exit 69
fi
echo "Conformance tests folder (read-only, resolved): $CONFORMANCE_TESTS_FOLDER"

echo "===== [4/8] Working directory setup (install-inline variant) ====="
WORKING_FOLDER="/tmp/swift_$(basename "$BUILD_FOLDER")"
echo "Working folder: $WORKING_FOLDER"
if [ -d "$WORKING_FOLDER" ]; then
    echo "+ find \"$WORKING_FOLDER\" -mindepth 1 -exec rm -rf {} +"
    find "$WORKING_FOLDER" -mindepth 1 -exec rm -rf {} +
else
    echo "+ mkdir -p \"$WORKING_FOLDER\""
    mkdir -p "$WORKING_FOLDER"
fi
trap 'echo "Cleaning up working folder: $WORKING_FOLDER"; rm -rf "$WORKING_FOLDER"' EXIT

echo "===== [5/8] Copy the build ====="
echo "+ cp -R \"$BUILD_FOLDER\"/. \"$WORKING_FOLDER\""
cp -R "$BUILD_FOLDER"/. "$WORKING_FOLDER"

echo "===== [6/8] Enter the working directory ====="
echo "Moving to: $WORKING_FOLDER"
cd "$WORKING_FOLDER" 2>/dev/null
if [ $? -ne 0 ]; then
    printf "Error: could not enter working folder '%s'.\n" "$WORKING_FOLDER" >&2
    exit 69
fi
echo "Now in: $(pwd)"

echo "===== [7/8] Install dependencies and stage conformance tests ====="
START_TIME=$(date +%s)
echo "Scratch path: ./.build  Cache path: ./.spm-cache (both inside $WORKING_FOLDER)"
echo "+ swift package --scratch-path ./.build --cache-path ./.spm-cache resolve"
swift package --scratch-path ./.build --cache-path ./.spm-cache resolve || exit $?
END_TIME=$(date +%s)
echo "Requirements setup completed in $((END_TIME - START_TIME)) seconds"
echo "Staging conformance test sources into ./Tests/ConformanceTests (inside the working folder only)"
echo "+ mkdir -p ./Tests/ConformanceTests"
mkdir -p ./Tests/ConformanceTests
echo "+ cp -R \"$CONFORMANCE_TESTS_FOLDER\"/. ./Tests/ConformanceTests/"
cp -R "$CONFORMANCE_TESTS_FOLDER"/. ./Tests/ConformanceTests/

echo "===== [8/8] Run the conformance tests ====="
# No --filter: suite names are renderer-chosen, so a name filter can silently match
# zero tests. The staged package's full suite runs (unit + overlaid conformance).
TEST_CMD="swift test --scratch-path ./.build --cache-path ./.spm-cache"
echo "Running: $TEST_CMD (from $(pwd), tests loaded from $CONFORMANCE_TESTS_FOLDER)"
output=$($TEST_CMD 2>&1)
TEST_EXIT=$?
echo "$output"
# Zero-tests guard: `swift test` runs both the Swift Testing and XCTest harnesses;
# the one without matching tests always prints a zero-count summary, so the guard
# must check that NEITHER harness ran a positive number of tests.
if ! echo "$output" | grep -Eq "Test run with [1-9][0-9]* test|Executed [1-9][0-9]* test"; then
    printf "Error: no conformance tests were discovered or executed.\n" >&2
    echo "===== Summary ====="
    echo "Variant: install-inline | Command: $TEST_CMD | Exit: 1 (no tests discovered)"
    echo "Conformance tests folder: $CONFORMANCE_TESTS_FOLDER | Working folder: $WORKING_FOLDER"
    exit 1
fi
echo "===== Summary ====="
echo "Variant: install-inline | Command: $TEST_CMD | Exit: $TEST_EXIT"
echo "Conformance tests folder: $CONFORMANCE_TESTS_FOLDER | Working folder: $WORKING_FOLDER"
exit $TEST_EXIT
