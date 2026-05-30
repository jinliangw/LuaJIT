#!/bin/bash
set -e

TARGET=$1
if [ -z "$TARGET" ]; then
    echo "Usage: $0 <arm64|armv7|x64>"
    exit 1
fi

case $TARGET in
    arm64)
        IMAGE="dockcross/linux-arm64"
        CROSS_FILE="arm64-cross.ini"
        CROSS_PREFIX="aarch64-unknown-linux-gnu-"
        MAKE_FLAGS=""
        ;;
    armv7)
        IMAGE="dockcross/linux-armv7"
        CROSS_FILE="armv7-cross.ini"
        CROSS_PREFIX="armv7-unknown-linux-gnueabi-"
        # For armv7 (32-bit), we use the cross-compiler for host tools and run them via qemu-arm
        # This avoids the pointer size mismatch issue without needing gcc-multilib on the host.
        MAKE_FLAGS="HOST_CC=${CROSS_PREFIX}gcc MINILUA_T='qemu-arm host/minilua' BUILDVM_T='qemu-arm host/buildvm'"
        ;;
    x64)
        IMAGE="dockcross/linux-x64"
        CROSS_FILE="x64-cross.ini"
        CROSS_PREFIX="x86_64-linux-gnu-"
        MAKE_FLAGS=""
        ;;
    *)
        echo "Unsupported target: $TARGET"
        exit 1
        ;;
esac

DOCKCROSS_BIN="./dockcross-$TARGET"
BUILD_DIR="build-$TARGET"
SRC_HOST="src-host"
SRC_TARGET="src-target-$TARGET"

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

echo "Building LuaJIT core (host and $TARGET)..."

# Build host LuaJIT incrementally in a separate directory
# This is used for bytecode bundling during the Meson build
if [ ! -d "$SRC_HOST" ]; then
    echo "Creating $SRC_HOST for incremental host build..."
    cp -r src "$SRC_HOST"
fi
cp -u src/* "$SRC_HOST/" 2>/dev/null || true

echo "Building host LuaJIT..."
# We always build host LuaJIT as a native x86_64 binary for bundling.
# Force CC=gcc to avoid any cross-compiler being picked up from the environment.
# Also clean first to ensure no architecture pollution from previous target builds.
dx_run "make -C $SRC_HOST clean && make -C $SRC_HOST -j$(nproc) CC=gcc HOST_CC=gcc BUILDMODE=static"

# Build target LuaJIT incrementally in a separate directory
if [ ! -d "$SRC_TARGET" ]; then
    echo "Creating $SRC_TARGET for incremental target build..."
    cp -r src "$SRC_TARGET"
fi
cp -u src/* "$SRC_TARGET/" 2>/dev/null || true

echo "Building target LuaJIT ($TARGET)..."
dx_run "make -C $SRC_TARGET -j$(nproc) CROSS=$CROSS_PREFIX TARGET_SYS=Linux BUILDMODE=static $MAKE_FLAGS"

# Ensure Meson is ready
if [ ! -d "$BUILD_DIR" ]; then
    echo "Setting up Meson build directory $BUILD_DIR..."
    
    # For 32-bit targets like armv7, we need a 32-bit luajit for bytecode bundling.
    # The most reliable way is to use the target luajit via qemu.
    if [ "$TARGET" == "armv7" ]; then
        BUNDLE_LUAJIT="qemu-arm /work/$SRC_TARGET/luajit"
        # We need to create a wrapper script because Meson find_program needs an executable
        WRAPPER_HOST="$BUILD_DIR/luajit-wrapper.sh"
        WRAPPER_CONTAINER="/work/$BUILD_DIR/luajit-wrapper.sh"
        mkdir -p "$BUILD_DIR"
        echo '#!/bin/bash' > "$WRAPPER_HOST"
        echo "$BUNDLE_LUAJIT \"\$@\"" >> "$WRAPPER_HOST"
        chmod +x "$WRAPPER_HOST"
        HOST_LUAJIT_PATH="$WRAPPER_CONTAINER"
    else
        HOST_LUAJIT_PATH="/work/$SRC_HOST/luajit"
    fi

    dx_run "meson setup $BUILD_DIR --cross-file $CROSS_FILE -Dluajit_lib_dir=$SRC_TARGET -Dluajit_src_dir=$SRC_TARGET -Dhost_luajit=$HOST_LUAJIT_PATH"
fi

echo "Running Meson build for $TARGET..."
dx_run "export PATH=/work/$SRC_HOST:\$PATH && meson compile -C $BUILD_DIR"

echo "Build complete! Binary located at $BUILD_DIR/standalone-luajit"
