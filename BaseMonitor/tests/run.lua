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
local S = dofile("BaseMonitor/tests/stubs.lua")
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

do
  local slots = {
    S.handle({vol=750, maxVol=1000, mass=2000, id=11}), -- 75%
    nil,                                                  -- unlinked, skipped
    S.handle({vol=0, maxVol=0, mass=0, id=13}),          -- empty/zero-max guarded
    S.handle({throw=true, id=14}),                        -- read error -> ok=false
  }
  -- slots has a hole at index 2; build an explicit length-4 array:
  slots = {slots[1], nil, S.handle({vol=0,maxVol=0,mass=0,id=13}), S.handle({throw=true,id=14})}
  local getName = S.namer({[11]="T1 Ore", [13]="Pure T1", [14]="Glass"})
  local rows = BIM.buildRows(slots, getName)

  eq("rows count (skip nil)", #rows, 3)
  eq("row1 label", rows[1].label, "T1 Ore")
  eq("row1 pct", rows[1].pct, 75)
  eq("row1 ok", rows[1].ok, true)
  eq("zero-max pct guarded", rows[2].pct, 0)
  eq("zero-max ok", rows[2].ok, true)
  eq("error row ok=false", rows[3].ok, false)
  eq("error row label", rows[3].label, "Glass")
end

do
  local rows = {
    {label="B", vol=200, maxVol=1000, mass=0, pct=20, ok=true},
    {label="A", vol=900, maxVol=1000, mass=0, pct=90, ok=true},
    {label="C", vol=0,   maxVol=0,    mass=0, pct=0,  ok=false},
  }
  local desc = BIM.sortRows({rows[1],rows[2],rows[3]}, "fill-desc")
  eq("fill-desc top", desc[1].label, "A")
  local asc = BIM.sortRows({rows[1],rows[2],rows[3]}, "fill-asc")
  eq("fill-asc top", asc[1].pct, 0)
  local byname = BIM.sortRows({rows[1],rows[2]}, "name")
  eq("name sort", byname[1].label, "A")

  local agg = BIM.aggregate({rows[1],rows[2],rows[3]})
  eq("agg count ok-only", agg.count, 2)
  eq("agg totalVol", agg.totalVol, 1100)
  eq("agg totalMax", agg.totalMax, 2000)
  eq("agg pct", agg.pct, 55)
  local empty = BIM.aggregate({})
  eq("agg empty pct", empty.pct, 0)
end

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
