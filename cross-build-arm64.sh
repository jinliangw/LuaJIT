#!/bin/bash
set -e

# Configuration
DOCKCROSS_IMAGE="dockcross/linux-arm64"
DOCKCROSS_BIN="./dockcross-linux-arm64"
BUILD_DIR="build-arm64"

# Ensure dockcross helper script exists
if [ ! -f "$DOCKCROSS_BIN" ]; then
    echo "Fetching dockcross helper script..."
    docker run --rm "$DOCKCROSS_IMAGE" > "$DOCKCROSS_BIN" || { echo "Docker run failed. Is docker installed?"; exit 1; }
    chmod +x "$DOCKCROSS_BIN"
fi

# Helper to run commands inside dockcross
function dx_run() {
    "$DOCKCROSS_BIN" bash -c "$1"
}

echo "Building LuaJIT core (host and target)..."

# Build host LuaJIT incrementally in a separate directory
if [ ! -d "src-host" ]; then
    echo "Creating src-host for incremental host build..."
    cp -r src src-host
fi
# Sync src-host if src changed (simple check)
# In a real scenario, we might want rsync, but cp is okay for now if we want to be safe.
# Actually, for incremental build, we should only copy if newer.
cp -u src/* src-host/ 2>/dev/null || true

echo "Building host LuaJIT..."
dx_run "make -C src-host -j$(nproc) BUILDMODE=static"

# Build target LuaJIT incrementally in a separate directory
if [ ! -d "src-target" ]; then
    echo "Creating src-target for incremental target build..."
    cp -r src src-target
fi
cp -u src/* src-target/ 2>/dev/null || true

echo "Building target LuaJIT (arm64)..."
dx_run "make -C src-target -j$(nproc) HOST_CC=gcc CROSS=aarch64-unknown-linux-gnu- TARGET_SYS=Linux BUILDMODE=static"

# Ensure Meson is ready
if [ ! -d "$BUILD_DIR" ]; then
    echo "Setting up Meson build directory..."
    # We need to make sure host-luajit is in the PATH inside the container.
    # dockcross mounts the current dir as /work.
    dx_run "export PATH=/work/src-host:\$PATH && meson setup $BUILD_DIR --cross-file arm64-cross.ini"
fi

echo "Running Meson build..."
dx_run "export PATH=/work/src-host:\$PATH && meson compile -C $BUILD_DIR"

echo "Build complete! Binary located at $BUILD_DIR/standalone-luajit"

