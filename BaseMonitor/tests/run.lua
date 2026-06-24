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

do
  eq("level ok", BIM.classifyLevel(50, 75, 90), "ok")
  eq("level warn", BIM.classifyLevel(80, 75, 90), "warn")
  eq("level crit", BIM.classifyLevel(95, 75, 90), "crit")

  local function has(hay, needle) return hay:find(needle, 1, true) ~= nil end

  local model = {
    title = "BASE INVENTORY",
    warnPct = 75, critPct = 90, tick = 7,
    rows = {
      {label="T1 Ore", vol=750, maxVol=1000, mass=2000, pct=75, ok=true},
      {label="Glass", vol=0, maxVol=0, mass=0, pct=0, ok=false},
    },
    agg = {totalVol=750, totalMax=1000, pct=75, count=1},
  }
  local html = BIM.renderHTML(model)
  check("html has title", has(html, "BASE INVENTORY"))
  check("html has style", has(html, "<style"))
  check("html has scanline", has(html, "scanline"))
  check("html has row label", has(html, "T1 Ore"))
  check("html has bar width", has(html, "width:75"))
  check("html has warn color", has(html, "#fffb00"))
  check("html has offline", has(html, "OFFLINE"))
  check("html has refresh tick", has(html, "#7"))

  local emptyHtml = BIM.renderHTML({title="X", warnPct=75, critPct=90, tick=1, rows={}, agg={totalVol=0,totalMax=0,pct=0,count=0}})
  check("empty panel", has(emptyHtml, "No containers linked"))

  local errHtml = BIM.renderHTML({title="X", warnPct=75, critPct=90, tick=1, rows={}, agg={pct=0,count=0,totalVol=0,totalMax=0}, error="CORE not linked"})
  check("error panel", has(errHtml, "CORE not linked"))
end

do
  local screen = S.screen()
  local core = S.core({[11]="T1 Ore", [12]="Pure T1"})
  local slots = {
    S.handle({vol=900, maxVol=1000, mass=3000, id=11}),
    S.handle({vol=100, maxVol=1000, mass=400, id=12}),
  }
  local cfg = {warnPct=75, critPct=90, sortMode="fill-desc", title="BASE INVENTORY"}
  local html = BIM.run({core=core, screen=screen, slots=slots, config=cfg, tick=3})

  local function has(h, n) return h:find(n, 1, true) ~= nil end
  check("run returns html", type(html) == "string")
  check("screen received html", screen.last == html)
  check("run draws fuller first", has(html, "T1 Ore"))
  check("title used", has(html, "BASE INVENTORY"))

  -- nil screen -> nil, no crash
  local none = BIM.run({core=core, screen=nil, slots=slots, config=cfg, tick=1})
  check("nil screen -> nil", none == nil)

  -- nil core -> error panel drawn
  local s2 = S.screen()
  BIM.run({core=nil, screen=s2, slots=slots, config=cfg, tick=1})
  check("nil core error panel", s2.last:find("CORE", 1, true) ~= nil)
end

do
  S.installGlobals({
    names = {[21]="T1 Ore", [22]="Glass"},
    containers = { {vol=500,maxVol=1000,mass=1000,id=21}, {vol=250,maxVol=1000,mass=600,id=22} },
    exports = { refreshSeconds=8, warnPct=70, critPct=88, sortMode="name", title="MY BASE" },
  })
  BIM.start()
  check("start drew screen", _G.screen.last ~= nil)
  check("start used title", _G.screen.last:find("MY BASE", 1, true) ~= nil)
  eq("start set timer", _G.unit._timers["refresh"], 8)
  eq("tick counter init", BIM._tick, 0)

  BIM.tick()
  eq("tick increments", BIM._tick, 1)
  check("tick redrew", _G.screen.last:find("SYNC #1", 1, true) ~= nil)
end

do
  local f = io.open("BaseMonitor/BaseMonitor.conf", "r")
  check("conf exists", f ~= nil)
  if f then
    local conf = f:read("*a"); f:close()
    local function has(h, n) return h:find(n, 1, true) ~= nil end
    check("conf has core slot", has(conf, "class: CoreUnit"))
    check("conf has screen slot", has(conf, "class: ScreenUnit"))
    check("conf has container1", has(conf, "container1:"))
    check("conf has container24", has(conf, "container24:"))
    check("conf has ItemContainer", has(conf, "class: ItemContainer"))
    check("conf inlines source", has(conf, "function M.renderHTML"))
    check("conf calls start", has(conf, "BIM.start()"))
    check("conf calls tick", has(conf, "BIM.tick()"))
    check("conf has --export annotation", has(conf, "--export:"))
    check("conf has export refreshSeconds", has(conf, "local refreshSeconds = 5 --export"))
    check("conf bridges refreshSeconds to global", has(conf, "_G.refreshSeconds = refreshSeconds"))
    check("conf bridges title to global", has(conf, "_G.title = title"))
  end
end

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
