project('standalone-luajit', 'c',
  version: '2.1.0',
  default_options: ['c_std=gnu99', 'optimization=2']
)

cc = meson.get_compiler('c')

# Dependencies
m_dep = cc.find_library('m', required: false)
dl_dep = cc.find_library('dl', required: false)
thread_dep = dependency('threads')

# Include directories
inc = include_directories('src')
luasocket_inc = include_directories('external/luasocket/src')

# External module sources
lfs_src = files('external/luafilesystem/src/lfs.c')

cjson_src = files(
  'external/lua-cjson/lua_cjson.c',
  'external/lua-cjson/strbuf.c',
  'external/lua-cjson/fpconv.c'
)

luasocket_src = files(
  'external/luasocket/src/auxiliar.c',
  'external/luasocket/src/buffer.c',
  'external/luasocket/src/except.c',
  'external/luasocket/src/inet.c',
  'external/luasocket/src/io.c',
  'external/luasocket/src/luasocket.c',
  'external/luasocket/src/options.c',
  'external/luasocket/src/select.c',
  'external/luasocket/src/tcp.c',
  'external/luasocket/src/timeout.c',
  'external/luasocket/src/udp.c',
  'external/luasocket/src/usocket.c',
  'external/luasocket/src/mime.c',
  'external/luasocket/src/compat.c'
)

# Lua bytecode bundling
host_luajit = find_program('luajit', native: true)

lua_files = [
  ['src/jit/bc.lua', 'jit.bc', 'jit_bc'],
  ['src/jit/v.lua', 'jit.v', 'jit_v'],
  ['src/jit/dump.lua', 'jit.dump', 'jit_dump'],
  ['src/jit/p.lua', 'jit.p', 'jit_p'],
  ['src/jit/zone.lua', 'jit.zone', 'jit_zone'],
  ['src/jit/vmdef.lua', 'jit.vmdef', 'jit_vmdef'],
  ['src/jit/dis_arm64.lua', 'jit.dis_arm64', 'jit_dis_arm64'],
  ['external/luasocket/src/socket.lua', 'socket', 'socket'],
  ['external/luasocket/src/mime.lua', 'mime', 'mime'],
  ['external/luasocket/src/ltn12.lua', 'ltn12', 'ltn12'],
  ['external/luasocket/src/http.lua', 'socket.http', 'socket_http'],
  ['external/luasocket/src/tp.lua', 'socket.tp', 'socket_tp'],
  ['external/luasocket/src/ftp.lua', 'socket.ftp', 'socket_ftp'],
  ['external/luasocket/src/smtp.lua', 'socket.smtp', 'socket_smtp'],
  ['external/luasocket/src/url.lua', 'socket.url', 'socket_url'],
  ['external/luasocket/src/headers.lua', 'socket.headers', 'socket_headers'],
  ['external/luasocket/src/mbox.lua', 'socket.mbox', 'socket_mbox'],
  ['external/lua-cjson/lua/cjson/util.lua', 'cjson.util', 'cjson_util'],
]

lua_inputs = []
lua_mod_args = []
foreach f : lua_files
  lua_inputs += files(f[0])
  lua_mod_args += f[0] + ',' + f[1] + ',' + f[2]
endforeach

# We use a python script to generate the bundled_lua.c
gen_bundle_py = files('gen_bundle.py')

bundled_lua_c = custom_target('bundled_lua_c',
  input: lua_inputs,
  output: 'bundled_lua.c',
  command: [
    find_program('python3'), gen_bundle_py,
    '--host-luajit', host_luajit,
    '--output', '@OUTPUT@',
    '--src-dir', meson.current_source_dir(),
    '--modules', 
  ] + lua_mod_args
)

# LuaJIT library
luajit_lib = cc.find_library('luajit', dirs: meson.current_source_dir() / 'src-target')

# Executable
executable('standalone-luajit',
  'src/standalone.c',
  bundled_lua_c,
  lfs_src,
  cjson_src,
  luasocket_src,
  include_directories: [inc, luasocket_inc],
  dependencies: [m_dep, dl_dep, thread_dep, luajit_lib],
  c_args: ['-DLUASOCKET_INET_PTON'],
  link_args: ['-static'],
  install: true
)
