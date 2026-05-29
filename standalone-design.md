# Standalone luajit runtime

- only depends on stable Linux kernel system call
- cross build and static link luajit for arm64 using dockcross/linux-arm64 docker image.
- Also support LuaFileSystem, cjson, LuaSocket as git modules
- Pre-loads static modules (`lfs`, `cjson`, `socket.core`, `mime.core`) in `src/standalone.c`.
- Build artifacts are placed in `build-arm64/`.
- Submodule sources are patched during build and restored afterwards to maintain a clean state.
