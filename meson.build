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
luajit_src_dir = get_option('luajit_src_dir')
if luajit_src_dir == ''
  luajit_src_dir = 'src'
endif
inc = include_directories(luajit_src_dir)
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
host_luajit_path = get_option('host_luajit')
if host_luajit_path != ''
  host_luajit = find_program(host_luajit_path)
else
  host_luajit = find_program('luajit', native: true)
endif

# LuaJIT core files
lua_files = [
  [luajit_src_dir / 'jit/bc.lua', 'jit.bc', 'jit_bc'],
  [luajit_src_dir / 'jit/v.lua', 'jit.v', 'jit_v'],
  [luajit_src_dir / 'jit/dump.lua', 'jit.dump', 'jit_dump'],
  [luajit_src_dir / 'jit/p.lua', 'jit.p', 'jit_p'],
  [luajit_src_dir / 'jit/zone.lua', 'jit.zone', 'jit_zone'],
  [luajit_src_dir / 'jit/vmdef.lua', 'jit.vmdef', 'jit_vmdef'],
]

# Architecture-specific disassembler
cpu_family = host_machine.cpu_family()
if cpu_family == 'aarch64'
  lua_files += [[luajit_src_dir / 'jit/dis_arm64.lua', 'jit.dis_arm64', 'jit_dis_arm64']]
elif cpu_family == 'arm'
  lua_files += [[luajit_src_dir / 'jit/dis_arm.lua', 'jit.dis_arm', 'jit_dis_arm']]
elif cpu_family == 'x86_64'
  lua_files += [
    [luajit_src_dir / 'jit/dis_x64.lua', 'jit.dis_x64', 'jit_dis_x64'],
    [luajit_src_dir / 'jit/dis_x86.lua', 'jit.dis_x86', 'jit_dis_x86']
  ]
endif

# External modules
lua_files += [
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
  ['external/penlight/lua/pl/init.lua', 'pl', 'pl'],
  ['external/penlight/lua/pl/app.lua', 'pl.app', 'pl_app'],
  ['external/penlight/lua/pl/array2d.lua', 'pl.array2d', 'pl_array2d'],
  ['external/penlight/lua/pl/class.lua', 'pl.class', 'pl_class'],
  ['external/penlight/lua/pl/compat.lua', 'pl.compat', 'pl_compat'],
  ['external/penlight/lua/pl/comprehension.lua', 'pl.comprehension', 'pl_comprehension'],
  ['external/penlight/lua/pl/config.lua', 'pl.config', 'pl_config'],
  ['external/penlight/lua/pl/data.lua', 'pl.data', 'pl_data'],
  ['external/penlight/lua/pl/Date.lua', 'pl.Date', 'pl_Date'],
  ['external/penlight/lua/pl/dir.lua', 'pl.dir', 'pl_dir'],
  ['external/penlight/lua/pl/file.lua', 'pl.file', 'pl_file'],
  ['external/penlight/lua/pl/func.lua', 'pl.func', 'pl_func'],
  ['external/penlight/lua/pl/import_into.lua', 'pl.import_into', 'pl_import_into'],
  ['external/penlight/lua/pl/input.lua', 'pl.input', 'pl_input'],
  ['external/penlight/lua/pl/lapp.lua', 'pl.lapp', 'pl_lapp'],
  ['external/penlight/lua/pl/lexer.lua', 'pl.lexer', 'pl_lexer'],
  ['external/penlight/lua/pl/List.lua', 'pl.List', 'pl_List'],
  ['external/penlight/lua/pl/luabalanced.lua', 'pl.luabalanced', 'pl_luabalanced'],
  ['external/penlight/lua/pl/Map.lua', 'pl.Map', 'pl_Map'],
  ['external/penlight/lua/pl/MultiMap.lua', 'pl.MultiMap', 'pl_MultiMap'],
  ['external/penlight/lua/pl/operator.lua', 'pl.operator', 'pl_operator'],
  ['external/penlight/lua/pl/OrderedMap.lua', 'pl.OrderedMap', 'pl_OrderedMap'],
  ['external/penlight/lua/pl/path.lua', 'pl.path', 'pl_path'],
  ['external/penlight/lua/pl/permute.lua', 'pl.permute', 'pl_permute'],
  ['external/penlight/lua/pl/pretty.lua', 'pl.pretty', 'pl_pretty'],
  ['external/penlight/lua/pl/Set.lua', 'pl.Set', 'pl_Set'],
  ['external/penlight/lua/pl/seq.lua', 'pl.seq', 'pl_seq'],
  ['external/penlight/lua/pl/sip.lua', 'pl.sip', 'pl_sip'],
  ['external/penlight/lua/pl/strict.lua', 'pl.strict', 'pl_strict'],
  ['external/penlight/lua/pl/stringio.lua', 'pl.stringio', 'pl_stringio'],
  ['external/penlight/lua/pl/stringx.lua', 'pl.stringx', 'pl_stringx'],
  ['external/penlight/lua/pl/tablex.lua', 'pl.tablex', 'pl_tablex'],
  ['external/penlight/lua/pl/template.lua', 'pl.template', 'pl_template'],
  ['external/penlight/lua/pl/test.lua', 'pl.test', 'pl_test'],
  ['external/penlight/lua/pl/text.lua', 'pl.text', 'pl_text'],
  ['external/penlight/lua/pl/types.lua', 'pl.types', 'pl_types'],
  ['external/penlight/lua/pl/url.lua', 'pl.url', 'pl_url'],
  ['external/penlight/lua/pl/utils.lua', 'pl.utils', 'pl_utils'],
  ['external/penlight/lua/pl/xml.lua', 'pl.xml', 'pl_xml'],
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
luajit_lib_dir = get_option('luajit_lib_dir')
if luajit_lib_dir == ''
  luajit_lib_dir = 'src-target'
endif

# find_library needs absolute paths for 'dirs'
if not luajit_lib_dir.startswith('/')
  luajit_lib_full_dir = meson.current_source_dir() / luajit_lib_dir
else
  luajit_lib_full_dir = luajit_lib_dir
endif

luajit_lib = cc.find_library('luajit', dirs: luajit_lib_full_dir)

# Executable
executable('luajit-standalone',
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
