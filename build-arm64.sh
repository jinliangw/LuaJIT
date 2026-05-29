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

# Create build directory
mkdir -p "$BUILD_DIR"

# Helper to run commands inside dockcross
function dx_run() {
    "$DOCKCROSS_BIN" bash -c "$1"
}

echo "Building LuaJIT for arm64..."
# Build LuaJIT statically. We use BUILDMODE=static to avoid .so build errors with -static flags.
dx_run "make clean && make -j$(nproc) HOST_CC=gcc CROSS=aarch64-unknown-linux-gnu- TARGET_SYS=Linux BUILDMODE=static"

# Copy libluajit.a and headers to build directory
cp src/libluajit.a "$BUILD_DIR/"
mkdir -p "$BUILD_DIR/include"
cp src/lua.h src/lualib.h src/lauxlib.h src/luaconf.h src/lua.hpp src/luajit.h "$BUILD_DIR/include/"

echo "Building external modules..."

# LuaFileSystem
echo "Building LuaFileSystem..."
dx_run "cd external/luafilesystem && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -c src/lfs.c -o src/lfs.o && \
       aarch64-unknown-linux-gnu-ar rcs ../../$BUILD_DIR/liblfs.a src/lfs.o"

# lua-cjson
echo "Building lua-cjson..."
# Patch lua_cjson.c to avoid conflict with LuaJIT's luaL_setfuncs (only if not already patched)
if ! grep -q "cjson_luaL_setfuncs" external/lua-cjson/lua_cjson.c; then
    sed -i 's/static void luaL_setfuncs/static void cjson_luaL_setfuncs/' external/lua-cjson/lua_cjson.c
    sed -i 's/luaL_setfuncs(l, reg, 1)/cjson_luaL_setfuncs(l, reg, 1)/' external/lua-cjson/lua_cjson.c
fi
dx_run "cd external/lua-cjson && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -c lua_cjson.c -o lua_cjson.o && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -c strbuf.c -o strbuf.o && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -c fpconv.c -o fpconv.o && \
       aarch64-unknown-linux-gnu-ar rcs ../../$BUILD_DIR/libcjson.a lua_cjson.o strbuf.o fpconv.o"

# luasocket
echo "Building luasocket..."
# We compile both socket and mime cores into the same static library for simplicity
dx_run "cd external/luasocket && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -Isrc -DLUASOCKET_INET_PTON -c src/auxiliar.c -o src/auxiliar.o && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -Isrc -DLUASOCKET_INET_PTON -c src/buffer.c -o src/buffer.o && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -Isrc -DLUASOCKET_INET_PTON -c src/except.c -o src/except.o && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -Isrc -DLUASOCKET_INET_PTON -c src/inet.c -o src/inet.o && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -Isrc -DLUASOCKET_INET_PTON -c src/io.c -o src/io.o && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -Isrc -DLUASOCKET_INET_PTON -c src/luasocket.c -o src/luasocket.o && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -Isrc -DLUASOCKET_INET_PTON -c src/options.c -o src/options.o && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -Isrc -DLUASOCKET_INET_PTON -c src/select.c -o src/select.o && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -Isrc -DLUASOCKET_INET_PTON -c src/tcp.c -o src/tcp.o && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -Isrc -DLUASOCKET_INET_PTON -c src/timeout.c -o src/timeout.o && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -Isrc -DLUASOCKET_INET_PTON -c src/udp.c -o src/udp.o && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -Isrc -DLUASOCKET_INET_PTON -c src/usocket.c -o src/usocket.o && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -Isrc -DLUASOCKET_INET_PTON -c src/mime.c -o src/mime.o && \
       aarch64-unknown-linux-gnu-gcc -O2 -I../../src -Isrc -DLUASOCKET_INET_PTON -c src/compat.c -o src/compat.o && \
       aarch64-unknown-linux-gnu-ar rcs ../../$BUILD_DIR/libluasocket.a src/auxiliar.o src/buffer.o src/except.o src/inet.o src/io.o src/luasocket.o src/options.o src/select.o src/tcp.o src/timeout.o src/udp.o src/usocket.o src/mime.o src/compat.o"

echo "Final linking of standalone-luajit..."
# Link everything statically. -static is used here to ensure no dynamic dependencies.
# Note: Static linking with glibc may still have runtime dependencies for things like NSS.
dx_run "aarch64-unknown-linux-gnu-gcc -O2 -static -I$BUILD_DIR/include \
       src/standalone.c \
       -L$BUILD_DIR -lluajit -llfs -lcjson -lluasocket \
       -lm -ldl -lpthread \
       -o $BUILD_DIR/standalone-luajit"

# Restore lua_cjson.c after build
echo "Restoring lua_cjson.c..."
cd external/lua-cjson && git checkout lua_cjson.c && cd ../..

echo "Build complete! Binary located at $BUILD_DIR/standalone-luajit"
