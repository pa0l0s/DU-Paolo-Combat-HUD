-- Manifest-driven test runner. Run: lua tests/run.lua
local dir = arg[0]:match("^(.*[/\\])") or "./"
package.path = dir .. "../src/?.lua;" .. dir .. "?.lua;" .. package.path

local T = { passed = 0, failed = 0, failures = {} }
function T.eq(actual, expected, msg)
  if actual ~= expected then
    T.failed = T.failed + 1
    table.insert(T.failures, (msg or "assertion")
      .. string.format(" — expected %q, got %q", tostring(expected), tostring(actual)))
  else
    T.passed = T.passed + 1
  end
end
function T.ok(cond, msg) T.eq(cond and true or false, true, msg) end
_G.T = T

local manifest = require("manifest")
for _, name in ipairs(manifest) do
  local ok, err = pcall(require, name)
  if not ok then
    T.failed = T.failed + 1
    table.insert(T.failures, name .. " errored: " .. tostring(err))
  end
end

print(string.format("\n%d passed, %d failed", T.passed, T.failed))
for _, f in ipairs(T.failures) do print("  FAIL: " .. f) end
os.exit(T.failed == 0 and 0 or 1)
