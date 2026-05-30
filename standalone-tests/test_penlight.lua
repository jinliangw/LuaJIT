local pl = require "pl.import_into"()
local tablex = require "pl.tablex"
local stringx = require "pl.stringx"
local pretty = require "pl.pretty"
local utils = require "pl.utils"
local path = require "pl.path"

print("Penlight version: " .. (pl._VERSION or "unknown"))

-- Test tablex
local t1 = {1, 2, 3}
local t2 = {1, 2, 3}
assert(tablex.deepcompare(t1, t2))
print("tablex.deepcompare: PASSED")

-- Test stringx
local s = "  hello world  "
assert(stringx.strip(s) == "hello world")
print("stringx.strip: PASSED")

-- Test pretty
local t = { a = 1, b = { c = 2 } }
local s_pretty = pretty.write(t)
assert(s_pretty:find("a = 1"))
assert(s_pretty:find("c = 2"))
print("pretty.write: PASSED")

-- Test path (pure Lua part)
assert(path.extension("test.lua") == ".lua")
print("path.extension: PASSED")

-- Test utils
local res = utils.split("a,b,c", ",")
assert(tablex.deepcompare(res, {"a", "b", "c"}))
print("utils.split: PASSED")

print("All Penlight tests: PASSED")
