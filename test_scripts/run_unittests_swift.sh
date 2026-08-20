#!/bin/bash
# run_unittests_swift.sh — run the unit tests of a generated Swift (SPM) build folder.
#
# Usage: run_unittests_swift.sh <build-folder>
#
# Exit codes:
#   1  — bad usage (missing argument)
#   2  — filesystem problem (couldn't enter the working folder)
#   69 — required toolchain (swift) is not installed
#   *  — otherwise, the exit code of `swift test` is propagated

echo "===== [1/7] Toolchain check ====="
if ! command -v swift >/dev/null 2>&1; then
    printf "Error: swift toolchain is not installed or not on PATH.\n" >&2
    exit 69
fi
echo "swift resolved at: $(command -v swift)"
swift --version

echo "===== [2/7] Argument validation ====="
if [ -z "$1" ]; then
    printf "Usage: %s <build-folder>\n" "$0" >&2
    exit 1
fi
SOURCE_FOLDER="$1"
if [ ! -d "$SOURCE_FOLDER" ]; then
    printf "Error: build folder '%s' does not exist or is not a directory.\n" "$SOURCE_FOLDER" >&2
    exit 2
fi
echo "Source build folder (read-only): $SOURCE_FOLDER"

echo "===== [3/7] Working directory setup ====="
WORKING_FOLDER="/tmp/swift_$(basename "$SOURCE_FOLDER")"
echo "Working folder: $WORKING_FOLDER"
if [ -d "$WORKING_FOLDER" ]; then
    echo "+ find \"$WORKING_FOLDER\" -mindepth 1 -exec rm -rf {} +"
    find "$WORKING_FOLDER" -mindepth 1 -exec rm -rf {} +
else
    echo "+ mkdir -p \"$WORKING_FOLDER\""
    mkdir -p "$WORKING_FOLDER"
fi
trap 'echo "Cleaning up working folder: $WORKING_FOLDER"; rm -rf "$WORKING_FOLDER"' EXIT

echo "===== [4/7] Copy the build ====="
echo "+ cp -R \"$SOURCE_FOLDER\"/. \"$WORKING_FOLDER\""
cp -R "$SOURCE_FOLDER"/. "$WORKING_FOLDER"

echo "===== [5/7] Enter the working directory ====="
echo "Moving to: $WORKING_FOLDER"
cd "$WORKING_FOLDER"
if [ $? -ne 0 ]; then
    printf "Error: could not enter working folder '%s'.\n" "$WORKING_FOLDER" >&2
    exit 2
fi
echo "Now in: $(pwd)"

echo "===== [6/7] Resolve dependencies (isolated) ====="
echo "Scratch path: ./.build  Cache path: ./.spm-cache (both inside $WORKING_FOLDER)"
echo "+ swift package --scratch-path ./.build --cache-path ./.spm-cache resolve"
swift package --scratch-path ./.build --cache-path ./.spm-cache resolve || exit $?

echo "===== [7/7] Run the unit tests ====="
echo "+ swift test --scratch-path ./.build --cache-path ./.spm-cache"
swift test --scratch-path ./.build --cache-path ./.spm-cache
TEST_EXIT=$?
echo "===== Summary ====="
echo "Test command: swift test --scratch-path ./.build --cache-path ./.spm-cache"
echo "Working folder: $WORKING_FOLDER"
echo "Exit code: $TEST_EXIT"
exit $TEST_EXIT
