#!/bin/bash
set -e

TARGET=$1
if [ -z "$TARGET" ]; then
    echo "Usage: $0 <arm64|armv7sf|x64>"
    echo "  arm64:   ARMv8 64-bit."
    echo "  armv7sf: ARMv7 without FPU (soft-float, optimized for v7)."
    echo "  x64:     Standard 64-bit Linux."
    exit 1
fi

case $TARGET in
    arm64)
        IMAGE="dockcross/linux-arm64"
        CROSS_FILE="arm64-cross.ini"
        CROSS_PREFIX="aarch64-unknown-linux-gnu-"
        MAKE_FLAGS=""
        QEMU="qemu-aarch64"
        ;;
    armv7sf)
        IMAGE="dockcross/linux-armv5"
        CROSS_FILE="armv7sf-cross.ini"
        CROSS_PREFIX="armv5-unknown-linux-gnueabi-"
        EXTRA_CFLAGS="-march=armv7-a"
        MAKE_FLAGS="HOST_CC=${CROSS_PREFIX}gcc MINILUA_T='qemu-arm host/minilua' BUILDVM_T='qemu-arm host/buildvm' TARGET_CFLAGS='$EXTRA_CFLAGS'"
        QEMU="qemu-arm"
        ;;
    x64)
        IMAGE="dockcross/linux-x64"
        CROSS_FILE="x64-cross.ini"
        CROSS_PREFIX="x86_64-linux-gnu-"
        MAKE_FLAGS=""
        QEMU=""
        ;;
    *)
        echo "Unsupported target: $TARGET"
        exit 1
        ;;
esac

DOCKCROSS_BIN="./dockcross-$TARGET"
BUILD_DIR="build-$TARGET"
SRC_TARGET="$BUILD_DIR/src-target"

# Ensure dockcross helper script exists
if [ ! -f "$DOCKCROSS_BIN" ]; then
    echo "Fetching dockcross helper script for $TARGET..."
    docker run --rm "$IMAGE" > "$DOCKCROSS_BIN" || { echo "Docker run failed. Is docker installed?"; exit 1; }
    chmod +x "$DOCKCROSS_BIN"
fi

# Helper to run commands inside dockcross
function dx_run() {
    "$DOCKCROSS_BIN" bash -c "$1"
}

echo "Building LuaJIT core ($TARGET)..."

# Build target LuaJIT incrementally in a separate directory
if [ ! -d "$SRC_TARGET" ]; then
    echo "Creating $SRC_TARGET for incremental target build..."
    mkdir -p "$BUILD_DIR"
    cp -r src "$SRC_TARGET"
    cp -r dynasm "$BUILD_DIR/dynasm"
fi
cp -u src/* "$SRC_TARGET/" 2>/dev/null || true
cp -u dynasm/* "$BUILD_DIR/dynasm/" 2>/dev/null || true

echo "Building target LuaJIT ($TARGET)..."
dx_run "make -C $SRC_TARGET -j$(nproc) CROSS=$CROSS_PREFIX TARGET_SYS=Linux BUILDMODE=static $MAKE_FLAGS"

# Ensure Meson is ready
if [ ! -d "$BUILD_DIR/meson-private" ]; then
    echo "Setting up Meson build directory $BUILD_DIR..."
    
    # Create a wrapper script because Meson find_program needs an executable.
    # We use the target LuaJIT (possibly via QEMU) to compile bytecode.
    WRAPPER_HOST="$BUILD_DIR/luajit-wrapper.sh"
    WRAPPER_CONTAINER="/work/$BUILD_DIR/luajit-wrapper.sh"
    mkdir -p "$BUILD_DIR"
    echo '#!/bin/bash' > "$WRAPPER_HOST"
    if [ -n "$QEMU" ]; then
        echo "$QEMU /work/$SRC_TARGET/luajit \"\$@\"" >> "$WRAPPER_HOST"
    else
        echo "/work/$SRC_TARGET/luajit \"\$@\"" >> "$WRAPPER_HOST"
    fi
    chmod +x "$WRAPPER_HOST"
    HOST_LUAJIT_PATH="$WRAPPER_CONTAINER"

    dx_run "meson setup $BUILD_DIR --cross-file $CROSS_FILE -Dluajit_lib_dir=$SRC_TARGET -Dluajit_src_dir=$SRC_TARGET -Dhost_luajit=$HOST_LUAJIT_PATH -Dc_args='$EXTRA_CFLAGS' -Dc_link_args='$EXTRA_CFLAGS'"
fi

echo "Running Meson build for $TARGET..."
dx_run "meson compile -C $BUILD_DIR"

echo "Stripping $TARGET binary..."
dx_run "${CROSS_PREFIX}strip $BUILD_DIR/luajit-standalone"

echo "Build complete! Binary located at $BUILD_DIR/luajit-standalone"
