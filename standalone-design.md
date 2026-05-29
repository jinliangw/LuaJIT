# Standalone luajit runtime

- only depends on stable Linux kernel system call
- cross build and static link luajit for arm64 using dockcross/linux-arm64 docker image.
- Also support LuaFileSystem, cjson, LuaSocket as git modules
- Pre-loads static C modules (`lfs`, `cjson`, `socket.core`, `mime.core`) in `src/standalone.c`.
- **Embeds core Lua modules** as bytecode directly into the binary:
    - LuaJIT `jit.*` components.
    - LuaSocket's Lua-side components (`socket`, `mime`, `ltn12`, `socket.http`, etc.).
    - cjson utility modules.
- Full LuaJIT interpreter functionality supported (cli flags, REPL).
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
- **Analysis:** LFS is a pure C module. Its entire API is contained within the compiled C archive, requiring no supplemental `.lua` files for operation.
