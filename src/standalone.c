#include <stdio.h>
#include <stdlib.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

// External module declarations
int luaopen_lfs(lua_State *L);
int luaopen_cjson(lua_State *L);
int luaopen_socket_core(lua_State *L);
int luaopen_mime_core(lua_State *L);

static void preload_modules(lua_State *L) {
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "preload");

    lua_pushcfunction(L, luaopen_lfs);
    lua_setfield(L, -2, "lfs");

    lua_pushcfunction(L, luaopen_cjson);
    lua_setfield(L, -2, "cjson");

    lua_pushcfunction(L, luaopen_socket_core);
    lua_setfield(L, -2, "socket.core");

    lua_pushcfunction(L, luaopen_mime_core);
    lua_setfield(L, -2, "mime.core");

    lua_pop(L, 2);
}

int main(int argc, char **argv) {
    lua_State *L = luaL_newstate();
    if (!L) {
        fprintf(stderr, "Failed to create Lua state\n");
        return 1;
    }
    luaL_openlibs(L);
    preload_modules(L);

    if (argc < 2) {
        fprintf(stderr, "Usage: %s <script.lua> [args...]\n", argv[0]);
        lua_close(L);
        return 1;
    }

    // Push arguments to global 'arg' table
    lua_newtable(L);
    for (int i = 0; i < argc; i++) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setglobal(L, "arg");

    // Load and run the script
    if (luaL_dofile(L, argv[1])) {
        fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));
        lua_close(L);
        return 1;
    }

    lua_close(L);
    return 0;
}
