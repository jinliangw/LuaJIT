#!/bin/bash
# Test runner for standalone-luajit
# Should be run from the project root

STANDALONE_BIN="build-arm64/standalone-luajit"
DOCKCROSS="./dockcross-linux-arm64"
TEST_DIR="standalone-tests"

if [ ! -f "$STANDALONE_BIN" ]; then
    echo "Error: $STANDALONE_BIN not found. Run ./cross-build-arm64.sh first."
    exit 1
fi

if [ ! -f "$DOCKCROSS" ]; then
    echo "Error: $DOCKCROSS not found."
    exit 1
fi

echo "Starting standalone-luajit test suite..."
echo "----------------------------------------"

FAILED=0
TOTAL=0

run_test() {
    local full_path=$1
    local test_file=$(basename "$full_path")
    TOTAL=$((TOTAL+1))
    echo -n "Running $test_file... "
    
    # Run via qemu inside dockcross. 
    # We cd into TEST_DIR inside the container so relative paths work.
    output=$($DOCKCROSS bash -c "cd $TEST_DIR && qemu-aarch64 ../$STANDALONE_BIN $test_file" 2>&1)
    
    if [ $? -eq 0 ]; then
        echo "PASSED"
    else
        echo "FAILED"
        echo "Output: $output"
        FAILED=$((FAILED+1))
    fi
}

# Run tests
for t in "$TEST_DIR"/test_*.lua; do
    run_test "$t"
done

echo "----------------------------------------"
echo "Tests completed: $TOTAL, Passed: $((TOTAL-FAILED)), Failed: $FAILED"

if [ $FAILED -ne 0 ]; then
    exit 1
fi
exit 0
