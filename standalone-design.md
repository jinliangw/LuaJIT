# Standalone luajit runtime

- **Zero External Dependencies**: Only depends on stable Linux kernel system calls.
- **Multi-Architecture Support**: Supports `arm64`, `armv7sf` (soft-float ARMv7), and `x64`.
- **Integrated C Modules**: Includes `LuaFileSystem`, `lua-cjson`, and `LuaSocket` as built-in components.
- **Integrated Lua Libraries**: Includes the full `Penlight` suite for utility functions (path, dir, tablex, stringx, etc.).
- **Embedded Lua Bytecode**: Core Lua modules are embedded as pre-compiled bytecode directly into the binary:
    - LuaJIT `jit.*` components (including architecture-specific disassemblers).
    - LuaSocket's Lua-side components (`socket`, `mime`, `ltn12`, `socket.http`, etc.).
    - `cjson.util` and `cjson.safe`.
    - `pl.*` (Penlight) modules.
- **Full Interpreter Functionality**: Supports all standard LuaJIT CLI flags (`-e`, `-i`, `-j`, etc.) and the REPL.
- **New Option `-m`**: Prints a comprehensive list of all supported modules, including standard LuaJIT libraries and all bundled/pre-loaded modules.
- **Incremental Meson Build**: Uses Meson for fast, reliable builds and dependency management.

## Build System & Automation

The project uses a unified build system capable of cross-compiling for multiple targets from a 64-bit Linux host.

### 1. Unified Cross-Build Script
The `cross-build.sh <target>` script manages the entire build process, including:
- Fetching and managing target-specific `dockcross` Docker environments.
- Managing independent build directories (`build-<target>/`) to ensure incremental builds don't conflict between architectures.
- Handling 32-bit/64-bit pointer size mismatches during bytecode generation by using QEMU to run target-native tools on the host.

### 2. Meson Integration
Transitioning to Meson allowed for:
- **True Incremental Builds**: Files are only recompiled if they or their dependencies change.
- **Automated Bundling**: `gen_bundle.py` is integrated as a `custom_target`, automatically re-generating the embedded C arrays when Lua sources or the bundling tool change.
- **Sanitized Submodules**: Custom logic in `gen_bundle.py` (e.g., truncating long strings in `cjson.util`) allows using upstream submodules without local modifications.

### 3. CI/Automation
The `build-and-test-all.sh` script provides a "one-touch" verification of the entire project across all supported architectures.

## Supported Architectures & Optimizations

| Target | Description | Toolchain / Image | Binary Size |
| :--- | :--- | :--- | :--- |
| **arm64** | ARMv8 64-bit | `dockcross/linux-arm64` | ~1.5M |
| **armv7sf** | ARMv7 Soft-Float (AST2600) | `dockcross/linux-armv5` | ~1.4M |
| **x64** | Standard 64-bit Linux | `dockcross/linux-x64` | ~2.0M |

### ARMv7 (AST2600) Optimization
The `armv7sf` target is specifically optimized for systems like the ASPEED AST2600. While it uses an "armv5" base for compatibility, it is compiled with `-march=armv7-a` to enable modern features:
- **Hardware Atomics**: Uses `ldrex`/`strex` for faster GC and memory management.
- **Thumb-2 ISA**: Mixed 16/32-bit instructions for better code density and cache utilization.
- **Soft-Float**: Strictly adheres to soft-float requirements while leveraging ARMv7 pipeline optimizations.

## Module Analysis & Selection Rationale

The selection of embedded `.lua` files ensures a "batteries-included" experience without a filesystem.

### 1. LuaJIT Core (JIT Libraries)
- **Source:** `src/jit/*.lua`
- **Selection:** Automatically bundles the core JIT control libraries (`bc.lua`, `v.lua`, `dump.lua`, etc.) and the **architecture-specific disassembler** (e.g., `dis_arm64.lua` for arm64, `dis_arm.lua` for armv7sf).

### 2. LuaSocket (Hybrid Module)
- **Source:** `external/luasocket/src/*.lua`
- **Rationale:** Bundles `socket.lua`, `mime.lua`, `ltn12.lua`, and all protocol implementations (`http`, `tp`, `ftp`, `smtp`, `url`, `headers`, `mbox`). This allows high-level protocols like HTTP to work out-of-the-box.

### 3. lua-cjson
- **Source:** `external/lua-cjson/lua/cjson/*.lua`
- **Included:** `cjson.util` and the `cjson.safe` variant.

### 4. Penlight
- **Source:** `external/penlight/lua/pl/*.lua`
- **Rationale:** Penlight provides a comprehensive set of utilities that complement the Lua standard library. We bundle all modules identified in `penlight-dev-1.rockspec` to ensure a "batteries-included" experience for tasks like path manipulation, directory listing, and advanced table/string operations.
- **Usage Notes:** Penlight supports three primary loading patterns in this runtime:
    - **Global Injection (Legacy):** `require "pl"` injects modules into the global `_G` table and returns `true`.
    - **Scoped Table (Recommended):** `local pl = require "pl.import_into"()` returns a clean table containing all modules without polluting `_G`.
    - **Surgical Loading:** `local tablex = require "pl.tablex"` loads only the specific module needed, which is the most efficient approach.

### 5. LuaFileSystem (Pure C)
- **Status:** Pure C module; integrated via static linking with no supplemental `.lua` files required.

## Performance Considerations: Startup Speed

Bundling and pre-loading modules does not negatively impact startup speed; it is often faster than standard installations.

### 1. Lazy Loading via `package.preload`
Modules are registered in `package.preload`, meaning they consume zero CPU time until actually `require`'d.

### 2. Elimination of Disk I/O
The VM performs an instantaneous memory lookup instead of a filesystem crawl (`LUA_PATH` search).

### 3. Pre-compiled Bytecode
Storing modules as bytecode skips the parsing and compilation phase during `require`, significantly speeding up module initialization.

## Verification & Testing

A comprehensive, multi-architecture test suite is provided in `standalone-tests/`.

### 1. Test Coverage
- **Core LuaJIT**: JIT availability, VM loops, FFI.
- **LFS**: Full directory and file operation suite.
- **lua-cjson**: Comprehensive encoding/decoding tests (100+ cases), including `cjson.safe`.
- **LuaSocket**: URL parsing, MIME encoding, and LTN12 filters.
- **Penlight**: Verification of `tablex`, `stringx`, `pretty`, and `path` utilities.

### 2. Automated Test Runner
`run_tests.sh` automates execution using:
- **Recursive Discovery**: Automatically finds all `test_*.lua` files in subdirectories.
- **Context-Aware Execution**: Switches to the test's directory before running, ensuring relative data file paths (common in `lua-cjson` tests) remain valid.
- **Cross-Architecture Emulation**: Uses the appropriate QEMU emulator for the target binary.
