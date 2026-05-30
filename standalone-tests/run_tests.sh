#!/bin/bash
# Test runner for standalone-luajit
# Should be run from the project root

TARGET=${1:-arm64}
BUILD_DIR="build-$TARGET"
STANDALONE_BIN="$BUILD_DIR/luajit-standalone"
DOCKCROSS="./dockcross-$TARGET"
TEST_DIR="standalone-tests"

case $TARGET in
    arm64) QEMU="qemu-aarch64" ;;
    armv7sf) QEMU="qemu-arm" ;;
    x64)   QEMU="" ;;
    *) echo "Unsupported target: $TARGET"; exit 1 ;;
esac

if [ ! -f "$STANDALONE_BIN" ]; then
    echo "Error: $STANDALONE_BIN not found. Run ./cross-build.sh $TARGET first."
    exit 1
fi

if [ ! -f "$DOCKCROSS" ]; then
    echo "Error: $DOCKCROSS not found."
    exit 1
fi

echo "Starting standalone-luajit test suite for $TARGET..."
echo "----------------------------------------------------"

FAILED=0
TOTAL=0

run_test() {
    local full_path=$1
    # Get path relative to TEST_DIR
    local relative_path=${full_path#$TEST_DIR/}
    local test_dir=$(dirname "$relative_path")
    local test_file=$(basename "$relative_path")
    
    TOTAL=$((TOTAL+1))
    echo -n "Running $relative_path... "
    
    # Run via qemu inside dockcross (if needed). 
    # We cd into the test's directory inside the container so relative paths work.
    if [ "$test_dir" = "." ]; then
        cd_cmd="cd $TEST_DIR"
        exec_path="../$STANDALONE_BIN"
    else
        cd_cmd="cd $TEST_DIR/$test_dir"
        exec_path="../../$STANDALONE_BIN"
    fi
    
    output=$($DOCKCROSS bash -c "$cd_cmd && $QEMU $exec_path $test_file" 2>&1)
    
    if [ $? -eq 0 ]; then
        echo "PASSED"
    else
        echo "FAILED"
        echo "Output: $output"
        FAILED=$((FAILED+1))
    fi
}

# Run tests
while read -r t; do
    run_test "$t"
done < <(find "$TEST_DIR" -name "test_*.lua" | sort)

echo "----------------------------------------"
echo "Tests completed: $TOTAL, Passed: $((TOTAL-FAILED)), Failed: $FAILED"

if [ $FAILED -ne 0 ]; then
    exit 1
fi
exit 0
