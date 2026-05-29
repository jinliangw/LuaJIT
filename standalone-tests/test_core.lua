-- Basic LuaJIT features test
local ffi = require("ffi")

-- Test FFI
local point = ffi.typeof("struct { int x, y; }")
local p = point(10, 20)
assert(p.x == 10)
assert(p.y == 20)
print("FFI test: Struct creation passed!")

-- Test JIT
if jit then
    print("JIT is available: " .. jit.version)
    jit.off()
    jit.on()
    print("JIT toggled successfully")
else
    error("JIT module not found")
end

-- Test a simple loop to ensure no crashes
local sum = 0
for i=1,1000 do sum = sum + i end
assert(sum == 500500)

print("LuaJIT core smoke test passed!")
