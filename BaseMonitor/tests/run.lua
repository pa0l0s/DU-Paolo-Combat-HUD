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
  -- buildRows takes a dense array of container/hub handles; labels via getName().
  local containers = {
    S.handle({vol=750, maxVol=1000, mass=2000, name="T1 Ore"}),  -- 75%
    S.handle({vol=0, maxVol=0, mass=0, name="Pure T1"}),         -- empty/zero-max guarded
    S.handle({throw=true, name="Glass"}),                        -- read error -> ok=false
    S.handle({vol=10, maxVol=100, mass=5, name=nil}),            -- no name -> fallback
  }
  local rows = BIM.buildRows(containers)

  eq("rows count", #rows, 4)
  eq("row1 label", rows[1].label, "T1 Ore")
  eq("row1 pct", rows[1].pct, 75)
  eq("row1 ok", rows[1].ok, true)
  eq("zero-max pct guarded", rows[2].pct, 0)
  eq("zero-max ok", rows[2].ok, true)
  eq("error row ok=false", rows[3].ok, false)
  eq("error row label", rows[3].label, "Glass")
  eq("noname fallback label", rows[4].label, "Container 4")
end

do
  -- itemLabel: build a label from container contents via system.getItem.
  local db = {
    [1] = {locDisplayName="Hematite", tier=1},
    [2] = {locDisplayName="Bauxite", tier=1},
    [3] = {locDisplayName="Coal", tier=1},
    [9] = {locDisplayName="Pure Iron", tier=2},
  }
  local getItem = function(id) return db[id] end

  eq("itemLabel tier+top2+overflow",
     BIM.itemLabel({{id=1,quantity=100},{id=2,quantity=50},{id=3,quantity=10}}, getItem),
     "T1 Hematite, Bauxite +1")
  eq("itemLabel single", BIM.itemLabel({{id=9,quantity=5}}, getItem), "T2 Pure Iron")
  eq("itemLabel mixed tier no prefix",
     BIM.itemLabel({{id=1,quantity=10},{id=9,quantity=5}}, getItem), "Hematite, Pure Iron")
  eq("itemLabel empty -> nil", BIM.itemLabel({}, getItem), nil)
  eq("itemLabel no getItem -> nil", BIM.itemLabel({{id=1,quantity=1}}, nil), nil)
  eq("itemLabel aggregates same id",
     BIM.itemLabel({{id=1,quantity=30},{id=1,quantity=70}}, getItem), "T1 Hematite")

  -- buildRows item/name modes.
  local cont = S.handle({vol=500, maxVol=1000, mass=900, name="Box A",
                         content={{id=1,quantity=100},{id=2,quantity=50}}})
  eq("buildRows items -> item names",
     BIM.buildRows({cont}, {getItem=getItem, labelMode="items"})[1].label, "T1 Hematite, Bauxite")
  eq("buildRows name -> custom name",
     BIM.buildRows({cont}, {getItem=getItem, labelMode="name"})[1].label, "Box A")
end

do
  -- classifyItem: coarse DU type + name patterns -> friendly category.
  eq("classify object", BIM.classifyItem({type="object", locDisplayName="Basic LED"}), "Objects")
  eq("classify worldMaterial", BIM.classifyItem({type="worldMaterial", locDisplayName="Glossy Silver"}), "Honeycomb")
  eq("classify pure", BIM.classifyItem({type="material", locDisplayName="Pure Iron"}), "Pure")
  eq("classify product", BIM.classifyItem({type="material", locDisplayName="Steel product"}), "Product")
  eq("classify fuel", BIM.classifyItem({type="material", locDisplayName="Nitron Fuel"}), "Fuel")
  eq("classify ore (default)", BIM.classifyItem({type="material", locDisplayName="Hematite"}), "Ore")
end

do
  -- categoryLabel: focused -> fine; two -> listed; mixed -> broad groups.
  local db = {
    [1]  = {locDisplayName="Hematite", type="material", tier=1},          -- Ore
    [2]  = {locDisplayName="Bauxite", type="material", tier=1},           -- Ore
    [9]  = {locDisplayName="Pure Iron", type="material", tier=2},         -- Pure
    [20] = {locDisplayName="Basic LED", type="object", tier=1},           -- Objects
    [21] = {locDisplayName="Steel product", type="material", tier=2},     -- Product
    [22] = {locDisplayName="Galvanized gray steel", type="worldMaterial", tier=1}, -- Honeycomb
  }
  local getItem = function(id) return db[id] end
  eq("category focused", BIM.categoryLabel({{id=1,quantity=10},{id=2,quantity=5}}, getItem), "T1 Ore")
  eq("category single", BIM.categoryLabel({{id=9,quantity=3}}, getItem), "T2 Pure")
  eq("category two-listed",
     BIM.categoryLabel({{id=1,quantity=10},{id=9,quantity=5}}, getItem), "T1-2 Ore & Pure")
  eq("category mixed -> broad",
     BIM.categoryLabel({{id=20,quantity=100},{id=1,quantity=50},{id=21,quantity=20},{id=22,quantity=10}}, getItem),
     "T1-2 Objects & Materials +1")
  eq("category empty -> nil", BIM.categoryLabel({}, getItem), nil)

  local cont = S.handle({vol=1, maxVol=2, mass=1, name="Box",
                         content={{id=1,quantity=10},{id=2,quantity=5}}})
  eq("buildRows category mode",
     BIM.buildRows({cont}, {getItem=getItem, labelMode="category"})[1].label, "T1 Ore")
end

do
  -- classify() splits linked slot handles into screen + containers by getClass().
  local scr = S.screen()
  local c1  = S.handle({vol=1, maxVol=2, mass=1, name="Ore", class="ItemContainerXL"})
  local hub = S.handle({vol=1, maxVol=2, mass=1, name="Hub", class="ItemContainerHub"})
  local sc = BIM.classify({ c1, scr, hub })  -- mixed order (dense)
  check("classify found screen", sc.screen == scr)
  eq("classify container count", #sc.containers, 2)
  eq("classify first container", sc.containers[1].getName(), "Ore")
  eq("classify hub matched", sc.containers[2].getName(), "Hub")

  local empty = BIM.classify({})
  check("classify empty screen nil", empty.screen == nil)
  eq("classify empty containers", #empty.containers, 0)
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

  local errHtml = BIM.renderHTML({title="X", warnPct=75, critPct=90, tick=1, rows={}, agg={pct=0,count=0,totalVol=0,totalMax=0}, error="SCAN ERROR"})
  check("error panel", has(errHtml, "SCAN ERROR"))
end

do
  -- run(env) with a screen + container list (no core).
  local screen = S.screen()
  local containers = {
    S.handle({vol=900, maxVol=1000, mass=3000, name="T1 Ore"}),
    S.handle({vol=100, maxVol=1000, mass=400, name="Pure T1"}),
  }
  local cfg = {warnPct=75, critPct=90, sortMode="fill-desc", title="BASE INVENTORY"}
  local data = BIM.run({screen=screen, containers=containers, config=cfg, tick=3})

  local function has(h, n) return h:find(n, 1, true) ~= nil end
  check("run returns data", type(data) == "string")
  check("screen got scriptInput", screen.input == data)
  check("data has container", has(data, "T1 Ore"))
  check("data has title", has(data, "BASE INVENTORY"))
  check("fuller sorted first", data:find("T1 Ore", 1, true) < data:find("Pure T1", 1, true))

  -- no screen still renders + returns data (no crash)
  local d2 = BIM.run({screen=nil, containers=containers, config={hud=false}, tick=1})
  check("no screen still returns data", type(d2) == "string")
end

do
  -- buildScreenData: header + per-row tab/newline encoding.
  local model = {
    title="BASE", build="b9", warnPct=75, critPct=90, tick=4,
    agg={pct=50, count=2, totalVol=0, totalMax=0},
    rows={
      {label="T1 Ore", vol=750, maxVol=1000, mass=2000, pct=75, ok=true},
      {label="Glass", vol=0, maxVol=0, mass=0, pct=0, ok=false},
    },
  }
  local d = BIM.buildScreenData(model)
  local hdr = d:match("^(.-)\n")
  local fields = {}
  for f in (hdr.."\t"):gmatch("(.-)\t") do fields[#fields+1]=f end
  eq("hdr title", fields[1], "BASE")
  eq("hdr build", fields[2], "b9")
  eq("hdr count", fields[4], "2")
  check("row has formatted volume", d:find("750 L", 1, true) ~= nil)
  check("offline row encoded", d:find("OFFLINE", 1, true) ~= nil)
end

do
  -- Bootstrap: install slot globals (mixed screen + containers), start with opts.
  S.installGlobals({
    slots = {
      S.handle({vol=500, maxVol=1000, mass=1000, name="T1 Ore"}),  -- slot1
      S.screen(),                                                  -- slot2
      S.handle({vol=250, maxVol=1000, mass=600, name="Glass"}),    -- slot3
    },
  })
  BIM.start({ refreshSeconds=8, warnPct=70, critPct=88, sortMode="name",
              title="MY BASE", build="t-1", hud=true })
  local scr = _G.slot2
  check("start activated screen", scr.activated == true)
  check("start installed render script", scr.rs ~= nil)
  check("render script uses screen API", scr.rs and scr.rs:find("getResolution", 1, true) ~= nil)
  check("start fed scriptInput", scr.input ~= nil)
  check("data has title", scr.input and scr.input:find("MY BASE", 1, true) ~= nil)
  check("data has build", scr.input and scr.input:find("t-1", 1, true) ~= nil)
  check("HUD mirror set", _G.system._hud ~= nil)
  check("HUD shown", _G.system._shown == true)
  eq("config from opts", BIM.config.warnPct, 70)
  eq("start set timer", _G.unit._timers["refresh"], 8)
  eq("tick counter init", BIM._tick, 0)

  local before = scr.input
  BIM.tick()
  eq("tick increments", BIM._tick, 1)
  check("tick refreshed data", scr.input ~= before)
end

do
  -- The generated board config.json (paste-into-board format).
  local f = io.open("BaseMonitor/BaseMonitor.config.json", "r")
  check("config.json exists", f ~= nil)
  if f then
    local j = f:read("*a"); f:close()
    local function has(h, n) return h:find(n, 1, true) ~= nil end
    check("json has slots", has(j, '"slots"'))
    check("json has slot1", has(j, '"slot1"'))
    check("json has slot10", has(j, '"slot10"'))
    check("json has unit slot", has(j, '"unit"'))
    check("json has handlers", has(j, '"handlers"'))
    check("json onStart signature", has(j, "onStart()"))
    check("json onTimer signature", has(j, "onTimer(timerId)"))
    check("json inlines source", has(j, "function M.renderHTML"))
    check("json calls start", has(j, "BIM.start("))
    check("json calls tick", has(j, "BIM.tick()"))
    check("json export refreshSeconds", has(j, "local refreshSeconds = 5 --export"))
    check("json start passes opts", has(j, "BIM.start({"))
    check("json passes title opt", has(j, "title = title"))
    check("json no _G usage", not has(j, "_G"))
    check("json strips trailing return M", not has(j, "return M"))
  end
end

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
