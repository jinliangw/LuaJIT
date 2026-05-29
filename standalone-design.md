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
