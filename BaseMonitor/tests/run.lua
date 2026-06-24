-- Minimal test runner. Run: lua54 BaseMonitor/tests/run.lua
local passed, failed = 0, 0
local function check(name, ok, msg)
  if ok then passed = passed + 1
  else failed = failed + 1; print("FAIL: " .. name .. " -- " .. tostring(msg)) end
end
local function eq(name, got, want)
  check(name, got == want, "got=" .. tostring(got) .. " want=" .. tostring(want))
end

-- Load the source under test (sets global BIM).
dofile("BaseMonitor/baseinventory.lua")
check("BIM table exists", type(BIM) == "table")

-- (more tests appended in later tasks, before the summary below)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
