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

eq("vol L", BIM.formatVolume(0), "0 L")
eq("vol L round", BIM.formatVolume(950), "950 L")
eq("vol kL", BIM.formatVolume(1500), "1.5 kL")
eq("vol ML", BIM.formatVolume(2500000), "2.5 ML")
eq("vol GL", BIM.formatVolume(3200000000), "3.2 GL")
eq("mass t", BIM.formatMass(1500), "1.5 t")
eq("mass t small", BIM.formatMass(0), "0.0 t")
eq("pct", BIM.formatPct(73.4), "73%")
eq("pct clamp hi", BIM.formatPct(140), "100%")
eq("pct clamp lo", BIM.formatPct(-5), "0%")

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
