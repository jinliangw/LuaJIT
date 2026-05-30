#!/bin/bash
set -e

TARGETS=("x64" "arm64" "armv7sf")
FAILED_TARGETS=()

echo "Starting full build and test cycle for all targets: ${TARGETS[*]}"
echo "================================================================"

for TARGET in "${TARGETS[@]}"; do
    echo ""
    echo "Processing target: $TARGET"
    echo "--------------------------"
    
    echo "Building $TARGET..."
    if ./cross-build.sh "$TARGET"; then
        echo "Build $TARGET successful."
    else
        echo "Build $TARGET FAILED."
        FAILED_TARGETS+=("$TARGET (build)")
        continue
    fi
    
    echo "Testing $TARGET..."
    if ./standalone-tests/run_tests.sh "$TARGET"; then
        echo "Tests for $TARGET PASSED."
    else
        echo "Tests for $TARGET FAILED."
        FAILED_TARGETS+=("$TARGET (test)")
    fi
done

echo ""
echo "================================================================"
if [ ${#FAILED_TARGETS[@]} -eq 0 ]; then
    echo "All targets built and tested successfully!"
    exit 0
else
    echo "The following targets had failures:"
    for FAILED in "${FAILED_TARGETS[@]}"; do
        echo "  - $FAILED"
    done
    exit 1
fi
