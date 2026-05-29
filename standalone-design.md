# Standalone luajit runtime

- only depends on stable Linux kernel system call
- cross build and static link luajit for arm64 using dockcross/linux-arm64 docker image.
- Also support LuaFileSystem, cjson, LuaSocket as git modules
- Pre-loads static C modules (`lfs`, `cjson`, `socket.core`, `mime.core`) in `src/standalone.c`.
- Embeds core Lua modules as bytecode directly into the binary:
    - LuaJIT `jit.*` components.
    - LuaSocket's Lua-side components (`socket`, `mime`, `ltn12`, `socket.http`, etc.).
    - cjson utility modules.
- Full LuaJIT interpreter functionality supported (cli flags, REPL).
- **New Option `-m`**: Prints a comprehensive list of all supported modules, including standard LuaJIT libraries and all bundled/pre-loaded modules.
- Build artifacts are placed in `build-arm64/`.

- Submodule sources are patched during build and restored afterwards to maintain a clean state.
- Produces a single, optimized, fully self-contained 1.4M binary.

## Module Analysis & Selection Rationale

The selection of embedded `.lua` files was determined by analyzing the source structure and Makefiles of each component to identify mandatory dependencies for a "standalone" experience.

### 1. LuaJIT Core (JIT Libraries)
- **Source:** `src/jit/*.lua`
- **Rationale:** These files are required for LuaJIT's high-level JIT control and introspection features (e.g., `-jdump`, `-jv`, `-jbc`). 
- **Key Files:** `bc.lua`, `v.lua`, `dump.lua`, `p.lua`, `zone.lua`, and the architecture-specific `dis_arm64.lua`. `vmdef.lua` (generated during build) is also included as it contains VM-specific constants used by these libraries.

### 2. LuaSocket (Hybrid Module)
- **Source:** `external/luasocket/src/*.lua`
- **Rationale:** LuaSocket follows a hybrid pattern where the low-level networking is in C (`socket.core`), but the public API and high-level protocols (HTTP, FTP, SMTP) are implemented in Lua.
- **Selection:** Mirrors the standard LuaSocket installation. We bundle `socket.lua` (the main entry point), `mime.lua`, `ltn12.lua`, and all protocol implementations (`http`, `tp`, `ftp`, `smtp`, `url`, `headers`, `mbox`) to ensure high-level modules like `socket.http` work without a filesystem.

### 3. lua-cjson
- **Source:** `external/lua-cjson/lua/cjson/*.lua`
- **Rationale:** While the core JSON logic is in C, the module often includes utility Lua scripts. `cjson.util` was bundled to provide the standard utility suite.

### 4. LuaFileSystem (Pure C)
- Analysis:** LFS is a pure C module. Its entire API is contained within the compiled C archive, requiring no supplemental `.lua` files for operation.

## Performance Considerations: Startup Speed

Bundling and pre-loading modules does not negatively impact the startup speed of `standalone-luajit`. In many cases, it is faster than a standard LuaJIT installation.

### 1. Lazy Loading via `package.preload`
Registering modules in `package.preload` is a lightweight operation that merely adds an entry to a lookup table. The actual module code is **not** executed or loaded into the Lua state until the first time `require("name")` is called in a script. If a module is never required, it consumes zero CPU time during the session.

### 2. Elimination of Disk I/O
A standard `require` call triggers a search of the filesystem (`LUA_PATH`/`LUA_CPATH`), involving multiple system calls and disk reads. In the standalone binary:
- **Search:** Instantaneous hash table lookup in memory.
- **Load:** Direct memory copy from the binary's data segment, bypassing all disk I/O.

### 3. Pre-compiled Bytecode
All bundled Lua modules are stored as **pre-compiled bytecode**. This allows the VM to skip the parsing and compilation phase that occurs when loading standard `.lua` source files, leading to faster module initialization.

### 4. Minimal Registration Overhead
The startup overhead consists of approximately 20 table insertions in `package.preload`. This process takes only a few microseconds and is negligible compared to the overall initialization of the LuaJIT VM.

### Comparison Summary
| Feature | Standard LuaJIT | Standalone LuaJIT |
| :--- | :--- | :--- |
| **Module Search** | Filesystem crawl (Slow) | Memory lookup (Instant) |
| **Module Loading** | Disk I/O | Memory segment (Fast) |
| **Processing** | Source parsing/compilation | Bytecode loading (Faster) |
| **Startup Overhead** | Negligible | Negligible (~20 table entries) |

