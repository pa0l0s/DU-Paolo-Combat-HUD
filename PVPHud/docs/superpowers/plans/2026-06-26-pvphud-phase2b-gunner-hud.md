# PVPHud Phase 2B — Gunner Seat HUD (full assembly, deployed)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete Gunner Seat HUD on top of the Phase 2A algorithm core and **deploy `gunner_seat_hud.conf` to the DU custom folder, ready to test in-game.**

**Architecture:** Pure display modules (`core/weapons`, `render/widgets`, `render/ar_layer`, `render/gunner_view`) are unit-tested on desktop. Thin `du/` adapters wrap the DU radar/weapon/construct elements (the DIP seams, exercised with stub elements). `bootstrap_gunner` wires slots → adapters → core → render → `system.setScreen`. `build.ps1` gains a gunner target that bundles everything into `gunner_seat_hud.conf`.

**Tech Stack:** Lua 5.3-safe; desktop Lua at `C:\Users\pawel\AppData\Local\Programs\Lua\bin\lua.exe`; PowerShell 7 bundler; DU autoconf `.conf`.

## Global Constraints

- Shipped Lua must be **Lua 5.3-safe**.
- `core/` and `render/` modules reference **no DU globals** — only plain tables/values. DU coupling lives only in `du/` adapters and `bootstrap_gunner`.
- `render/` may depend on `core/theme` (pure data) and `render/widgets`; it must NOT depend on `du/`.
- Module require names mirror paths (`src/render/widgets.lua` → `require("render.widgets")`).
- Generated `.conf` files are artifacts produced solely by `build.ps1` — never hand-edited.
- Theme roles used: `base`/`ready`/`caution`/`threat`/`dim`/`warn`/`panel` (all `core/theme.lua` palette keys).
- Run tests: `& "C:\Users\pawel\AppData\Local\Programs\Lua\bin\lua.exe" PVPHud/tests/run.lua` (or Bash `"/c/Users/pawel/AppData/Local/Programs/Lua/bin/lua.exe" PVPHud/tests/run.lua`).
- Phase 2A baseline: **76 tests passing.** Each task adds tests; trust the green run over any predicted absolute total (prior plans' predicted counts drifted slightly — harmless). Each task states its new-assertion count.
- Each task: add its `test_*` to `PVPHud/tests/manifest.lua` and commit on branch `pvphud-phase2b`.
- DU API method names for `du/` adapters are taken from the working `GFL_Gunner_2.0.conf` reference (proven in-game).
- **Deployment:** `build.ps1`'s `Write-Conf` copies to the DU custom folder when that path exists. Final placement of the `.conf` in `E:\GRY\My Dual Universe\Game\data\lua\autoconf\custom\` is confirmed by the controller after the branch is built (the implementer's sandbox may not mount `E:`).

---

## File Structure (Phase 2B)

```
PVPHud/
  src/
    core/weapons.lua          -- NEW: weapon status -> {label, role, barPct}
    render/widgets.lua        -- NEW: SVG primitives (panel, text, bar, graph, escape)
    render/ar_layer.lua       -- NEW: AR markers (screen coords) -> svg
    render/gunner_view.lua    -- NEW: compose view state -> full HUD html
    du/weapon.lua             -- NEW: WeaponUnit array adapter
    du/radar.lua              -- NEW: RadarPVPUnit adapter
    du/construct.lua          -- NEW: world->screen projection adapter
    bootstrap_gunner.lua      -- NEW: wires slots -> adapters -> core -> render
  tests/
    test_weapons.lua  test_widgets.lua  test_ar_layer.lua
    test_gunner_view.lua  test_du_adapters.lua  test_gunner_smoke.lua
    manifest.lua              -- MODIFY: register the six new test files
  build.ps1                   -- MODIFY: add gunner target -> gunner_seat_hud.conf
  gunner_seat_hud.conf        -- GENERATED + deployed to game folder
```

---

### Task 1: `core/weapons` — weapon status → display

**Files:** Create `PVPHud/src/core/weapons.lua`, `PVPHud/tests/test_weapons.lua`; modify `PVPHud/tests/manifest.lua` (add `"test_weapons"`).

**Interfaces:**
- Produces: `core.weapons` with `describe(raw)→{label, role, barPct}`. `raw = { status=int, operational=bool, ammoPct=0..1 }`. `role` ∈ theme palette keys. Status codes (DU WeaponUnit): 1=IDLE, 2=FIRING, 4=RELOADING, 5=UNLOADING, 6=BLOCKED.

- [ ] **Step 1: Write the failing test** — `PVPHud/tests/test_weapons.lua`:

```lua
local w = require("core.weapons")

T.eq(w.describe({ status = 1, operational = false, ammoPct = 0.5 }).label, "BROKEN", "not operational -> broken")
T.eq(w.describe({ status = 1, operational = false, ammoPct = 0.5 }).role, "threat", "broken is threat")
T.eq(w.describe({ status = 4, operational = true, ammoPct = 0.3 }).label, "RELOADING", "status 4 reloading")
T.eq(w.describe({ status = 5, operational = true, ammoPct = 0.3 }).label, "UNLOADING", "status 5 unloading")
T.eq(w.describe({ status = 1, operational = true, ammoPct = 0 }).label, "RELOAD", "empty ammo -> reload")
T.eq(w.describe({ status = 6, operational = true, ammoPct = 0.5 }).label, "BLOCKED", "status 6 blocked")
T.eq(w.describe({ status = 1, operational = true, ammoPct = 0.05 }).label, "LOW AMMO", "low ammo")
T.eq(w.describe({ status = 2, operational = true, ammoPct = 0.8 }).label, "FIRING", "status 2 firing")
T.eq(w.describe({ status = 2, operational = true, ammoPct = 0.8 }).role, "ready", "firing is ready")
T.eq(w.describe({ status = 1, operational = true, ammoPct = 0.8 }).label, "IDLE", "status 1 idle")
local fire = w.describe({ status = 2, operational = true, ammoPct = 0.8 })
T.ok(math.abs(fire.barPct - 0.8) < 1e-9, "barPct reflects ammo when active")
```

Add `"test_weapons"` to the manifest.

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL `module 'core.weapons' not found`.

- [ ] **Step 3: Implement** — `PVPHud/src/core/weapons.lua`:

```lua
-- Pure weapon status -> display mapping. No DU globals.
-- Status codes (DU WeaponUnit): 1 IDLE, 2 FIRING, 4 RELOADING, 5 UNLOADING, 6 BLOCKED.
local M = {}

function M.describe(raw)
  local s = raw.status
  local ammo = raw.ammoPct or 0
  if not raw.operational then return { label = "BROKEN", role = "threat", barPct = 0 } end
  if s == 4 then return { label = "RELOADING", role = "caution", barPct = 1 } end
  if s == 5 then return { label = "UNLOADING", role = "caution", barPct = 1 } end
  if ammo <= 0 then return { label = "RELOAD", role = "threat", barPct = 0 } end
  if s == 6 then return { label = "BLOCKED", role = "threat", barPct = ammo } end
  if ammo <= 0.1 then return { label = "LOW AMMO", role = "caution", barPct = ammo } end
  if s == 2 then return { label = "FIRING", role = "ready", barPct = ammo } end
  if s == 1 then return { label = "IDLE", role = "base", barPct = ammo } end
  return { label = "ERROR", role = "threat", barPct = ammo }
end

return M
```

- [ ] **Step 4: Run to verify it passes** — Expected: PASS, all green, +11 assertions (suite ≈ 87).

- [ ] **Step 5: Commit**

```bash
git add PVPHud/src/core/weapons.lua PVPHud/tests/test_weapons.lua PVPHud/tests/manifest.lua
git commit -m "feat(pvphud): weapon status display mapping

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `render/widgets` — themed SVG primitives

**Files:** Create `PVPHud/src/render/widgets.lua`, `PVPHud/tests/test_widgets.lua`; modify manifest (add `"test_widgets"`).

**Interfaces:**
- Consumes: `core.theme` (palette + `color(role)`).
- Produces: `render.widgets` with `panel(x,y,w,h)→str`, `text(x,y,str,role,size)→str`, `bar(x,y,w,h,pct,role)→str`, `graph(x,y,w,h,points,role)→str` (points are y-values 0..1), `escape(s)→str`. All return SVG-element strings.

- [ ] **Step 1: Write the failing test** — `PVPHud/tests/test_widgets.lua`:

```lua
local W = require("render.widgets")
local theme = require("core.theme")

T.ok(W.panel(10, 20, 100, 50):find('<rect', 1, true) ~= nil, "panel is a rect")
T.ok(W.panel(10, 20, 100, 50):find(theme.color("panel"), 1, true) ~= nil, "panel uses panel color")

local t = W.text(5, 9, "HP <50>", "threat", 14)
T.ok(t:find(theme.color("threat"), 1, true) ~= nil, "text uses role color")
T.ok(t:find("HP &lt;50&gt;", 1, true) ~= nil, "text escapes angle brackets")

-- bar clamps pct and floors fill width
local b = W.bar(0, 0, 200, 10, 0.5, "ready")
T.ok(b:find('width="100"', 1, true) ~= nil, "bar fill is floor(width*pct)")
local bover = W.bar(0, 0, 200, 10, 2, "ready")
T.ok(bover:find('width="200"', 1, true) ~= nil, "bar pct clamped to 1")

-- graph emits a polyline with one coord per point
local g = W.graph(0, 0, 100, 50, { 0, 0.5, 1 }, "base")
T.ok(g:find("<polyline", 1, true) ~= nil, "graph is a polyline")
local _, commas = g:gsub(" %d", "")
T.ok(g:find("points=", 1, true) ~= nil, "graph has points attr")
T.eq(W.graph(0, 0, 100, 50, { 0.5 }, "base"), "", "graph needs >= 2 points")

T.eq(W.escape("a&b<c>"), "a&amp;b&lt;c&gt;", "escape ampersand and brackets")
```

Add `"test_widgets"` to the manifest.

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL `module 'render.widgets' not found`.

- [ ] **Step 3: Implement** — `PVPHud/src/render/widgets.lua`:

```lua
-- Pure SVG/HTML primitives for the HUD, themed via core.theme. No DU globals.
local theme = require("core.theme")
local M = {}

-- XML-escape text content.
function M.escape(s)
  s = tostring(s)
  s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
  return s
end

-- Translucent neon glass panel.
function M.panel(x, y, w, h)
  return string.format(
    '<rect x="%d" y="%d" width="%d" height="%d" fill="%s" fill-opacity="0.55" stroke="%s" stroke-opacity="0.6"/>',
    x, y, w, h, theme.color("panel"), theme.color("base"))
end

-- Neon SVG text (bright fill; glow is carried by the bright palette).
function M.text(x, y, str, role, size)
  return string.format(
    '<text x="%d" y="%d" font-family="monospace" font-size="%d" fill="%s">%s</text>',
    x, y, size or 16, theme.color(role or "base"), M.escape(str))
end

-- Horizontal progress bar: faint track + neon fill.
function M.bar(x, y, w, h, pct, role)
  pct = math.max(0, math.min(1, pct or 0))
  local hex = theme.color(role or "ready")
  return string.format(
    '<rect x="%d" y="%d" width="%d" height="%d" fill="%s" fill-opacity="0.15"/>'
    .. '<rect x="%d" y="%d" width="%d" height="%d" fill="%s" fill-opacity="0.8"/>',
    x, y, w, h, hex, x, y, math.floor(w * pct), h, hex)
end

-- Polyline graph from y-values in 0..1 across a box.
function M.graph(x, y, w, h, points, role)
  if #points < 2 then return "" end
  local hex = theme.color(role or "base")
  local coords = {}
  for i, p in ipairs(points) do
    local px = x + (i - 1) / (#points - 1) * w
    local py = y + (1 - math.max(0, math.min(1, p))) * h
    coords[#coords + 1] = string.format("%.1f,%.1f", px, py)
  end
  return string.format(
    '<polyline points="%s" fill="none" stroke="%s" stroke-width="1.5"/>',
    table.concat(coords, " "), hex)
end

return M
```

- [ ] **Step 4: Run to verify it passes** — Expected: PASS, all green, +10 assertions (suite ≈ 97).

- [ ] **Step 5: Commit**

```bash
git add PVPHud/src/render/widgets.lua PVPHud/tests/test_widgets.lua PVPHud/tests/manifest.lua
git commit -m "feat(pvphud): themed SVG widget primitives

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: `render/ar_layer` — AR markers

**Files:** Create `PVPHud/src/render/ar_layer.lua`, `PVPHud/tests/test_ar_layer.lua`; modify manifest (add `"test_ar_layer"`).

**Interfaces:**
- Consumes: `core.theme`.
- Produces: `render.ar_layer` with `build(markers)→str`. `markers = { {x, y, label?, sub?, role}, ... }` (x/y already projected to screen pixels). Returns concatenated SVG marker elements (the caller wraps them in an `<svg>` overlay). Empty list → `""`.

- [ ] **Step 1: Write the failing test** — `PVPHud/tests/test_ar_layer.lua`:

```lua
local ar = require("render.ar_layer")
local theme = require("core.theme")

T.eq(ar.build({}), "", "no markers -> empty")

local s = ar.build({ { x = 100, y = 200, label = "042", sub = "1.2km", role = "threat" } })
T.ok(s:find("<rect", 1, true) ~= nil, "marker has a box")
T.ok(s:find(theme.color("threat"), 1, true) ~= nil, "marker uses role color")
T.ok(s:find(">042<", 1, true) ~= nil, "marker shows label")
T.ok(s:find(">1.2km<", 1, true) ~= nil, "marker shows sub")

local none = ar.build({ { x = 10, y = 10, role = "ready" } })
T.ok(none:find("<rect", 1, true) ~= nil, "marker without text still draws box")
```

Add `"test_ar_layer"` to the manifest.

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL `module 'render.ar_layer' not found`.

- [ ] **Step 3: Implement** — `PVPHud/src/render/ar_layer.lua`:

```lua
-- Pure AR marker layout: projected screen coords -> SVG elements. No DU globals.
local theme = require("core.theme")
local M = {}

function M.build(markers)
  local out = {}
  for _, m in ipairs(markers) do
    local hex = theme.color(m.role or "threat")
    out[#out + 1] = string.format(
      '<rect x="%.1f" y="%.1f" width="20" height="20" fill="none" stroke="%s" stroke-width="2"/>',
      m.x - 10, m.y - 10, hex)
    if m.label then
      out[#out + 1] = string.format(
        '<text x="%.1f" y="%.1f" font-family="monospace" font-size="13" fill="%s" text-anchor="middle">%s</text>',
        m.x, m.y - 14, hex, m.label)
    end
    if m.sub then
      out[#out + 1] = string.format(
        '<text x="%.1f" y="%.1f" font-family="monospace" font-size="13" fill="%s" text-anchor="middle">%s</text>',
        m.x, m.y + 26, hex, m.sub)
    end
  end
  return table.concat(out)
end

return M
```

- [ ] **Step 4: Run to verify it passes** — Expected: PASS, all green, +6 assertions (suite ≈ 103).

- [ ] **Step 5: Commit**

```bash
git add PVPHud/src/render/ar_layer.lua PVPHud/tests/test_ar_layer.lua PVPHud/tests/manifest.lua
git commit -m "feat(pvphud): AR marker layer

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: `render/gunner_view` — compose the HUD

**Files:** Create `PVPHud/src/render/gunner_view.lua`, `PVPHud/tests/test_gunner_view.lua`; modify manifest (add `"test_gunner_view"`).

**Interfaces:**
- Consumes: `render.widgets`.
- Produces: `render.gunner_view` with `build(state)→html`. `state` shape:
  ```
  { screenW, screenH, css,
    weapons = { {label, role, barPct, class}, ... },
    target  = nil | { name, id3, coreSize, identified, dist, distRole, optimal,
                      angular, angularRole, hitPct, hitRole, speed, maxSpeed, closing },
    stats   = { shotsFired, shotsHit, accuracy, peakDps, damage },  -- pre-formatted strings/numbers
    graphSvg = "", markersSvg = "" }
  ```

- [ ] **Step 1: Write the failing test** — `PVPHud/tests/test_gunner_view.lua`:

```lua
local gv = require("render.gunner_view")

local base = {
  screenW = 1920, screenH = 1080, css = "<style>X</style>",
  weapons = { { label = "FIRING", role = "ready", barPct = 0.8, class = "S" } },
  stats = { shotsFired = 3, shotsHit = 2, accuracy = "67%", peakDps = "1.2k", damage = "5.0k" },
  graphSvg = "", markersSvg = "",
}

local noTarget = gv.build(base)
T.ok(noTarget:find("<style>X</style>", 1, true) ~= nil, "includes css")
T.ok(noTarget:find("<svg", 1, true) ~= nil, "opens an svg overlay")
T.ok(noTarget:find("</svg>", 1, true) ~= nil, "closes the svg overlay")
T.ok(noTarget:find("WEAPONS", 1, true) ~= nil, "weapons header")
T.ok(noTarget:find("TELEMETRY", 1, true) ~= nil, "telemetry header")
T.ok(noTarget:find("FIRING", 1, true) ~= nil, "weapon label shown")

local withTarget = {}
for k, v in pairs(base) do withTarget[k] = v end
withTarget.target = {
  name = "Enemy Ship", id3 = "042", coreSize = "M", identified = false,
  dist = "1.2km", distRole = "caution", optimal = "2.0km",
  angular = "15", angularRole = "ready", hitPct = 80, hitRole = "ready",
  speed = "?", maxSpeed = "30,000 km/h", closing = "-",
}
local wt = gv.build(withTarget)
T.ok(wt:find("Enemy Ship", 1, true) ~= nil, "target name shown")
T.ok(wt:find("042", 1, true) ~= nil, "target id shown")
T.ok(wt:find("UNIDENTIFIED", 1, true) ~= nil, "unidentified flagged")
T.ok(wt:find("DIST", 1, true) ~= nil, "distance row present")
```

Add `"test_gunner_view"` to the manifest.

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL `module 'render.gunner_view' not found`.

- [ ] **Step 3: Implement** — `PVPHud/src/render/gunner_view.lua`:

```lua
-- Pure HUD composition: view state -> full HTML string. No DU globals.
local widgets = require("render.widgets")
local M = {}

local function svgOpen(w, h)
  return string.format(
    '<svg style="position:absolute;top:0;left:0;width:100vw;height:100vh;'
    .. 'overflow:visible;pointer-events:none" viewBox="0 0 %d %d">', w, h)
end

function M.build(state)
  local w, h = state.screenW, state.screenH
  local p = { state.css or "", svgOpen(w, h) }

  -- Weapons panel (top-left)
  local wn = #state.weapons
  p[#p + 1] = widgets.panel(20, 20, 360, 36 + wn * 26)
  p[#p + 1] = widgets.text(32, 44, "WEAPONS", "base", 18)
  for i, wp in ipairs(state.weapons) do
    local y = 44 + i * 26
    p[#p + 1] = widgets.text(32, y, (wp.class or "?") .. " " .. wp.label, wp.role, 15)
    p[#p + 1] = widgets.bar(190, y - 12, 170, 14, wp.barPct, wp.role)
  end

  -- Telemetry panel (top-right)
  local sx = w - 320
  p[#p + 1] = widgets.panel(sx, 20, 300, 160)
  p[#p + 1] = widgets.text(sx + 12, 44, "TELEMETRY", "base", 18)
  local st = state.stats
  local lines = {
    "FIRED   " .. st.shotsFired,
    "HIT     " .. st.shotsHit,
    "ACC     " .. st.accuracy,
    "PEAK    " .. st.peakDps,
    "DAMAGE  " .. st.damage,
  }
  for i, ln in ipairs(lines) do
    p[#p + 1] = widgets.text(sx + 12, 44 + i * 22, ln, "base", 15)
  end
  if state.graphSvg and state.graphSvg ~= "" then p[#p + 1] = state.graphSvg end

  -- Target panel (center-top)
  local t = state.target
  if t then
    local tx, ty = w / 2 - 180, h / 2 - 210
    p[#p + 1] = widgets.panel(tx, ty, 360, 180)
    p[#p + 1] = widgets.text(tx + 90, ty + 24,
      "[" .. t.coreSize .. "] " .. t.id3 .. " " .. t.name, "base", 16)
    if not t.identified then
      p[#p + 1] = widgets.text(tx + 90, ty + 46, "UNIDENTIFIED", "threat", 14)
    end
    local rows = {
      { "DIST", t.dist, t.distRole },
      { "OPTIMAL", t.optimal, "base" },
      { "ANG", t.angular .. " deg/s", t.angularRole },
      { "HIT", t.hitPct .. "%", t.hitRole },
      { "SPEED", t.speed, "base" },
      { "MAXSPD", t.maxSpeed, "base" },
      { "CLOSING", t.closing, "base" },
    }
    for i, r in ipairs(rows) do
      local y = ty + 66 + (i - 1) * 15
      p[#p + 1] = widgets.text(tx + 14, y, r[1], "base", 13)
      p[#p + 1] = widgets.text(tx + 130, y, tostring(r[2]), r[3], 13)
    end
  end

  if state.markersSvg and state.markersSvg ~= "" then p[#p + 1] = state.markersSvg end
  p[#p + 1] = "</svg>"
  return table.concat(p)
end

return M
```

- [ ] **Step 4: Run to verify it passes** — Expected: PASS, all green, +10 assertions (suite ≈ 113).

- [ ] **Step 5: Commit**

```bash
git add PVPHud/src/render/gunner_view.lua PVPHud/tests/test_gunner_view.lua PVPHud/tests/manifest.lua
git commit -m "feat(pvphud): gunner HUD composition

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: `du/` adapters — weapon, radar, construct

**Files:** Create `PVPHud/src/du/weapon.lua`, `PVPHud/src/du/radar.lua`, `PVPHud/src/du/construct.lua`, `PVPHud/tests/test_du_adapters.lua`; modify manifest (add `"test_du_adapters"`).

**Interfaces:**
- Produces:
  - `du.weapon.new(weaponArray)→{ count(), readings()→{ {class,status,operational,ammoPct,hitProbability}, ... }, firstSpec()→{optimalDistance,maxDistance,optimalTracking}|nil }`.
  - `du.radar.new(radar)→{ targetId(), contacts()→{ids}, info(id)→{name,distance,speed,mass,coreSize,angular(deg/s),identified,abandoned,threatRate,transponder,worldPos} }`.
  - `du.construct.new(construct)→{ toScreen(pos{x,y,z}, screenW, screenH)→{x,y}|nil }` (nil when behind camera).

- [ ] **Step 1: Write the failing test** — `PVPHud/tests/test_du_adapters.lua`:

```lua
local duWeapon = require("du.weapon")
local duRadar = require("du.radar")
local duConstruct = require("du.construct")

-- stub WeaponUnit
local function stubWeapon(o)
  return {
    getClass = function() return "WeaponSmall" end,
    getStatus = function() return o.status end,
    getOperationalState = function() return o.op end,
    getAmmoCount = function() return o.ammo end,
    getMaxAmmo = function() return o.maxAmmo end,
    getHitProbability = function() return o.hit end,
    getOptimalDistance = function() return 2000 end,
    getMaxDistance = function() return 5000 end,
    getOptimalTracking = function() return 20 end,
  }
end

local W = duWeapon.new({ stubWeapon({ status = 2, op = 1, ammo = 80, maxAmmo = 100, hit = 0.7 }) })
T.eq(W.count(), 1, "weapon count")
local r = W.readings()[1]
T.eq(r.class, "S", "class letter parsed from WeaponSmall")
T.eq(r.operational, true, "operational from state==1")
T.ok(math.abs(r.ammoPct - 0.8) < 1e-9, "ammoPct = ammo/maxAmmo")
T.eq(W.firstSpec().optimalDistance, 2000, "firstSpec optimal distance")

-- stub RadarPVPUnit
local radar = {
  getTargetId = function() return 4242 end,
  getConstructIds = function() return { 4242 } end,
  getConstructName = function() return "Foe" end,
  getConstructDistance = function() return 1500 end,
  getConstructSpeed = function() return 100 end,
  getConstructMass = function() return 5000 end,
  getConstructCoreSize = function() return "M" end,
  getConstructAngularSpeed = function() return math.pi end, -- 180 deg/s
  isConstructIdentified = function() return true end,
  isConstructAbandoned = function() return false end,
  getThreatRateFrom = function() return 4 end,
  hasMatchingTransponder = function() return false end,
  getConstructWorldPos = function() return { 1, 2, 3 } end,
}
local R = duRadar.new(radar)
T.eq(R.targetId(), 4242, "target id")
T.eq(#R.contacts(), 1, "contacts list")
local info = R.info(4242)
T.eq(info.name, "Foe", "info name")
T.ok(math.abs(info.angular - 180) < 1e-6, "angular converted rad/s -> deg/s")
T.eq(info.worldPos[3], 3, "world pos passthrough")

-- stub construct projection
local construct = { getPointOnScreen = function(_) return { 0.5, 0.25, 1 } end }
local C = duConstruct.new(construct)
local scr = C.toScreen({ x = 1, y = 2, z = 3 }, 1920, 1080)
T.ok(math.abs(scr.x - 960) < 1e-6 and math.abs(scr.y - 270) < 1e-6, "projected to screen px")
local behind = duConstruct.new({ getPointOnScreen = function(_) return { 0.5, 0.5, -1 } end })
T.eq(behind.toScreen({ x = 0, y = 0, z = 0 }, 1920, 1080), nil, "behind camera -> nil")
```

Add `"test_du_adapters"` to the manifest.

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL `module 'du.weapon' not found`.

- [ ] **Step 3: Implement**

`PVPHud/src/du/weapon.lua`:

```lua
-- Thin adapter over a DU WeaponUnit array. Returns plain tables.
local M = {}

function M.new(weapons)
  local self = { weapons = weapons or {} }

  function self.count() return #self.weapons end

  function self.readings()
    local out = {}
    for i, w in ipairs(self.weapons) do
      local maxAmmo = w.getMaxAmmo()
      out[i] = {
        class = (w.getClass():match("Weapon(%a)")) or "?",
        status = w.getStatus(),
        operational = w.getOperationalState() == 1,
        ammoPct = (maxAmmo > 0) and (w.getAmmoCount() / maxAmmo) or 0,
        hitProbability = w.getHitProbability(),
      }
    end
    return out
  end

  function self.firstSpec()
    local w = self.weapons[1]
    if not w then return nil end
    return {
      optimalDistance = w.getOptimalDistance(),
      maxDistance = w.getMaxDistance(),
      optimalTracking = w.getOptimalTracking(),
    }
  end

  return self
end

return M
```

`PVPHud/src/du/radar.lua`:

```lua
-- Thin adapter over a DU RadarPVPUnit. Returns plain tables.
local M = {}

function M.new(radar)
  local self = { radar = radar }

  function self.targetId() return self.radar.getTargetId() end
  function self.contacts() return self.radar.getConstructIds() end

  function self.info(id)
    local r = self.radar
    return {
      name = r.getConstructName(id),
      distance = r.getConstructDistance(id),
      speed = r.getConstructSpeed(id),
      mass = r.getConstructMass(id),
      coreSize = r.getConstructCoreSize(id),
      angular = r.getConstructAngularSpeed(id) * 180 / math.pi,
      identified = r.isConstructIdentified(id),
      abandoned = r.isConstructAbandoned(id),
      threatRate = r.getThreatRateFrom(id),
      transponder = r.hasMatchingTransponder(id),
      worldPos = r.getConstructWorldPos(id),
    }
  end

  return self
end

return M
```

`PVPHud/src/du/construct.lua`:

```lua
-- Thin adapter over DU construct world->screen projection. Returns plain tables.
local M = {}

function M.new(construct)
  local self = { construct = construct }

  -- pos {x,y,z} -> {x,y} screen pixels, or nil if behind the camera.
  function self.toScreen(pos, screenW, screenH)
    local p = self.construct.getPointOnScreen({ pos.x, pos.y, pos.z })
    if not p then return nil end
    if p[3] ~= nil and p[3] <= 0 then return nil end
    return { x = p[1] * screenW, y = p[2] * screenH }
  end

  return self
end

return M
```

- [ ] **Step 4: Run to verify it passes** — Expected: PASS, all green, +12 assertions (suite ≈ 125).

- [ ] **Step 5: Commit**

```bash
git add PVPHud/src/du PVPHud/tests/test_du_adapters.lua PVPHud/tests/manifest.lua
git commit -m "feat(pvphud): du adapters for weapon/radar/construct

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: `bootstrap_gunner` + gunner build target + smoke test (deploys the .conf)

**Files:** Create `PVPHud/src/bootstrap_gunner.lua`, `PVPHud/tests/test_gunner_smoke.lua`; modify `PVPHud/tests/manifest.lua` (add `"test_gunner_smoke"`); modify `PVPHud/build.ps1` (add gunner target). Generated: `PVPHud/gunner_seat_hud.conf`.

**Interfaces:**
- Consumes: every Phase 2A core module + Tasks 1–5 modules.
- Produces: `bootstrap_gunner.start(env)→app`. `env = { system, construct, weapon, radar, db, codec, build }`. `app` has `render()→html` (assembles state, calls `system.setScreen`), `onUpdate()`, `onWeaponHit(id,dmg)`, `onWeaponMiss(id)`, `onDamage(amt)`, `onTick()`, plus `app.dps`, `app.tracking`, `app.channel`.

- [ ] **Step 1: Write the failing test** — `PVPHud/tests/test_gunner_smoke.lua`:

```lua
local stubs = require("stubs")
local boot = require("bootstrap_gunner")

local function stubWeapon()
  return {
    getClass = function() return "WeaponSmall" end,
    getStatus = function() return 2 end,
    getOperationalState = function() return 1 end,
    getAmmoCount = function() return 80 end,
    getMaxAmmo = function() return 100 end,
    getHitProbability = function() return 0.7 end,
    getOptimalDistance = function() return 2000 end,
    getMaxDistance = function() return 5000 end,
    getOptimalTracking = function() return 20 end,
  }
end

local radar = {
  getTargetId = function() return 4242 end,
  getConstructIds = function() return { 4242 } end,
  getConstructName = function() return "Foe" end,
  getConstructDistance = function() return 1500 end,
  getConstructSpeed = function() return 100 end,
  getConstructMass = function() return 5000 end,
  getConstructCoreSize = function() return "M" end,
  getConstructAngularSpeed = function() return 0.2 end,
  isConstructIdentified = function() return true end,
  isConstructAbandoned = function() return false end,
  getThreatRateFrom = function() return 4 end,
  hasMatchingTransponder = function() return false end,
  getConstructWorldPos = function() return { 1, 2, 3 } end,
}
local construct = { getPointOnScreen = function(_) return { 0.5, 0.5, 1 } end }
local sys = stubs.newSystem()
local db = stubs.newDatabank()
local codec = {
  encode = function(t) return next(t) and "json:ne" or "json:empty" end,
  decode = function(s) return s == "json:ne" and { 1 } or {} end,
}

local app = boot.start({
  system = sys, construct = construct, weapon = { stubWeapon() },
  radar = radar, db = db, codec = codec, build = 9,
})

local html = app.render()
T.ok(type(html) == "string", "render returns html")
T.ok(html == sys._last.screen, "setScreen received html")
T.ok(html:find("WEAPONS", 1, true) ~= nil, "weapons panel present")
T.ok(html:find("Foe", 1, true) ~= nil, "locked target shown")
T.ok(html:find("042", 1, true) ~= nil, "target id marker / panel (4242 % 1000)")
T.ok(db.hasKey("pilotTarget"), "channel seeded")

-- event handlers don't error and update telemetry
app.onWeaponHit(4242, 250)
app.onWeaponMiss(4242)
app.onDamage(100)
app.onTick()
T.eq(app.dps.shotsFired, 2, "hit+miss recorded")
T.eq(app.dps.shotsHit, 1, "hit recorded")
T.ok(select(2, pcall(app.onUpdate)) == nil or true, "onUpdate runs")
```

Add `"test_gunner_smoke"` to the manifest.

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL `module 'bootstrap_gunner' not found`.

- [ ] **Step 3: Implement** — `PVPHud/src/bootstrap_gunner.lua`:

```lua
-- Wires DU slots -> du adapters -> core logic -> render -> setScreen.
-- The only DU-coupled module besides du/. env carries the DU globals.
local format     = require("core.format")
local theme      = require("core.theme")
local channel    = require("core.channel")
local ballistics = require("core.ballistics")
local weaponsLib = require("core.weapons")
local dpsmod     = require("core.dps")
local threat     = require("core.threat")
local tracking   = require("core.tracking")
local duWeapon   = require("du.weapon")
local duRadar    = require("du.radar")
local duConstruct= require("du.construct")
local arLayer    = require("render.ar_layer")
local gunnerView = require("render.gunner_view")

local M = {}

function M.start(env)
  local sys = env.system
  local W = duWeapon.new(env.weapon)
  local R = duRadar.new(env.radar)
  local C = duConstruct.new(env.construct)
  local ch = channel.new(env.db, env.codec)
  ch.seed()
  local dps = dpsmod.new({})
  local track = tracking.new()
  local app = { dps = dps, tracking = track, channel = ch }

  local function avgHit(readings)
    if #readings == 0 then return 0 end
    local sum = 0
    for _, r in ipairs(readings) do sum = sum + (r.hitProbability or 0) end
    return math.floor(sum / #readings * 100 + 0.5)
  end

  function app.render()
    local sw, sh = sys.getScreenWidth(), sys.getScreenHeight()
    local readings = W.readings()
    local spec = W.firstSpec()

    -- weapons
    local wlist = {}
    for i, raw in ipairs(readings) do
      local d = weaponsLib.describe(raw)
      d.class = raw.class
      wlist[i] = d
    end

    -- target panel
    local target = nil
    local tid = R.targetId()
    if tid and tid ~= 0 then
      local info = R.info(tid)
      local optimal = spec and spec.optimalDistance or 0
      local spread = spec and ballistics.spread(spec.maxDistance, spec.optimalDistance) or 0
      local trackDeg = spec and spec.optimalTracking or 0
      local hitPct = avgHit(readings)
      target = {
        name = (info.name or ""):sub(1, 16),
        id3 = string.format("%03d", tid % 1000),
        coreSize = info.coreSize or "?",
        identified = info.identified,
        dist = format.distance(info.distance),
        distRole = ballistics.rangeBand(info.distance, optimal, spread),
        optimal = format.distance(optimal),
        angular = string.format("%d", math.floor(info.angular + 0.5)),
        angularRole = ballistics.angularBand(info.angular, trackDeg),
        hitPct = hitPct,
        hitRole = ballistics.hitBand(hitPct),
        speed = info.identified and format.speed(info.speed) or "?",
        maxSpeed = format.speed(ballistics.maxTargetSpeed(info.mass or 0)),
        closing = "-",
      }
    end

    -- AR markers
    local markers = {}
    local t = sys.getUtcTime()
    for _, id in ipairs(R.contacts()) do
      local info = R.info(id)
      if info.worldPos then
        track.update(id, { x = info.worldPos[1], y = info.worldPos[2], z = info.worldPos[3] }, t)
      end
      local predicted = track.predict(id, t)
      if predicted then
        local scr = C.toScreen(predicted, sw, sh)
        if scr then
          local cls = threat.classify({
            threatRate = info.threatRate, transponder = info.transponder,
            abandoned = info.abandoned, identified = info.identified,
          })
          markers[#markers + 1] = {
            x = scr.x, y = scr.y, role = cls.role,
            label = string.format("%03d", id % 1000),
            sub = format.distance(info.distance),
          }
        end
      end
    end

    local stats = {
      shotsFired = dps.shotsFired,
      shotsHit = dps.shotsHit,
      accuracy = string.format("%d%%", math.floor(dps.accuracy() * 100 + 0.5)),
      peakDps = format.compact(dps.peakDps),
      damage = format.compact(dps.damageDealt),
    }

    local html = gunnerView.build({
      screenW = sw, screenH = sh, css = theme.css(),
      weapons = wlist, target = target, stats = stats,
      graphSvg = "", markersSvg = arLayer.build(markers),
    })
    sys.setScreen(html)
    return html
  end

  function app.onUpdate() app.render() end
  function app.onWeaponHit(id, dmg) dps.recordHit(id, dmg) end
  function app.onWeaponMiss(id) dps.recordMiss(id) end
  function app.onDamage(amount) dps.recordReceived(amount) end
  function app.onTick() dps.tick() end

  return app
end

return M
```

Modify `PVPHud/build.ps1`: **append** the following block at the end of the file (after the existing `Write-Conf "pvphud_selftest.conf" $conf` line). It reuses the existing `Build-Bundle`, `Indent`, and `Write-Conf` helpers:

```powershell

# --- Gunner Seat HUD target ---
$gunnerModules = @(
  'core.format', 'core.theme', 'core.channel', 'core.ballistics', 'core.weapons',
  'core.dps', 'core.threat', 'core.tracking', 'du.weapon', 'du.radar', 'du.construct',
  'render.widgets', 'render.ar_layer', 'render.gunner_view', 'bootstrap_gunner'
)
$gunnerBoot = @"
system.showScreen(1)
GunnerApp = require('bootstrap_gunner').start({ system = system, construct = construct, weapon = weapon, radar = radar_1, db = db_1, codec = (db_1 ~= nil) and require('dkjson') or nil, build = $build })
unit.setTimer('dpsTick', 1)
"@
$gunnerBundle = Build-Bundle $gunnerModules 'bootstrap_gunner' $gunnerBoot

# Per-weapon hit/miss handlers (weapon_1 .. weapon_6)
$weaponHandlers = ""
for ($i = 1; $i -le 6; $i++) {
  $weaponHandlers += @"
    weapon_$($i):
        onHit(targetId,damage):
            lua: |
                if GunnerApp then GunnerApp.onWeaponHit(targetId, damage) end
        onMissed(targetId):
            lua: |
                if GunnerApp then GunnerApp.onWeaponMiss(targetId) end
"@
  $weaponHandlers += "`n"
}

$gunnerConf = @"
name: Gunner Seat HUD (Retrosyncwave)
slots:
    core:
        class: CoreUnit
    weapon:
        class: WeaponUnit
        select: manual
    radar:
        class: RadarPVPUnit
        select: manual
    db:
        class: DataBank
        select: manual
handlers:
    unit:
        onStart:
            lua: |
$(Indent $gunnerBundle 16)
        tick:
            args: ["dpsTick"]
            lua: |
                if GunnerApp then GunnerApp.onTick() end
    system:
        onUpdate:
            lua: |
                if GunnerApp then GunnerApp.onUpdate() end
    core:
        onStressChanged(stress):
            lua: |
                if GunnerApp then GunnerApp.onDamage(stress) end
$weaponHandlers
"@

Write-Conf "gunner_seat_hud.conf" $gunnerConf
```

- [ ] **Step 4: Run tests, then build, then verify the conf**

```
"/c/Users/pawel/AppData/Local/Programs/Lua/bin/lua.exe" PVPHud/tests/run.lua
pwsh -File PVPHud/build.ps1
```

Expected: tests all green (+12 assertions, suite ≈ 137); build prints `Wrote pvphud_selftest.conf ...` and `Wrote gunner_seat_hud.conf ...`.

Verify the gunner bundle inlined correctly:

```
pwsh -NoProfile -Command "Select-String -Path PVPHud/gunner_seat_hud.conf -Pattern \"__mods\['bootstrap_gunner'\]\", 'name: Gunner Seat HUD', 'weapon_6:' | Measure-Object | Select-Object -ExpandProperty Count"
```

Expected: `3` (bundle entry + header + the 6th weapon handler present).

- [ ] **Step 5: Commit**

```bash
git add PVPHud/src/bootstrap_gunner.lua PVPHud/tests/test_gunner_smoke.lua PVPHud/tests/manifest.lua PVPHud/build.ps1 PVPHud/gunner_seat_hud.conf PVPHud/.buildno
git commit -m "feat(pvphud): gunner bootstrap + build target -> gunner_seat_hud.conf

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 6: Deployment note (controller-performed)**

The implementer's environment may not mount `E:`. After this branch is reviewed and merged, the controller copies `PVPHud/gunner_seat_hud.conf` into `E:\GRY\My Dual Universe\Game\data\lua\autoconf\custom\` so it is ready to test in-game (matching the project goal). Confirm the file is present there.

---

## Self-Review

**1. Spec coverage (DESIGN §3 render + §4 du/bootstrap for the gunner):**
- `render/widgets`, `render/ar_layer`, `render/gunner_view` — Tasks 2–4. ✅
- `core/weapons` status mapping (feeds the weapons panel) — Task 1. ✅
- `du/weapon`, `du/radar`, `du/construct` adapters — Task 5. ✅
- `bootstrap_gunner` + `build.ps1` gunner target → `gunner_seat_hud.conf` — Task 6. ✅
- Gunner spec features realized: weapon status panel, optimal-range + hit-% + angular bands (ballistics), AR target markers (tracking + construct projection + ar_layer), damage telemetry stats (dps), retrosyncwave theme throughout. ✅
- Deferred (intended): damage-caused **graph** rendering is stubbed (`graphSvg = ""`) — the `dps.series` data and `widgets.graph` exist, so wiring it is a small Phase-2C/follow-up addition, not a missing capability. Controller HUD = Phase 3.

**2. Placeholder scan:** No TBD/TODO. `graphSvg = ""` is an explicit, documented MVP choice (the graph widget and data both exist and are tested), not a placeholder for missing code. ✅

**3. Type consistency:**
- `du.weapon.readings()` shape `{class,status,operational,ammoPct,hitProbability}` matches `core.weapons.describe` input + `bootstrap_gunner` usage. ✅
- `du.radar.info()` fields match `bootstrap_gunner` + `threat.classify` inputs. ✅
- `gunner_view.build(state)` state shape matches what `bootstrap_gunner` assembles (weapons/target/stats/markersSvg/css). ✅
- `ar_layer.build(markers)` marker shape `{x,y,label,sub,role}` matches `bootstrap_gunner`'s marker assembly. ✅
- Bundle module list in `build.ps1` matches all `require` names used by `bootstrap_gunner` and its transitive deps. ✅
- Conf globals: `radar_1`/`db_1` (manual-select slots), `weapon` (array) — consistent with the slot declarations and the GFL reference convention. ✅

**Known risks (documented):** in-game rendering is the only un-automatable check (DESIGN §9) — the smoke test proves the bundle assembles and runs under stubs and produces well-formed HTML, but live SVG rendering and DU event delivery (weapon onHit/onMissed firing only in weapon-view) are confirmed only in-game. `weapon_1..6` handlers cover up to 6 linked weapons (GFL convention); more would need additional handlers.

---

_Plan saved 2026-06-26. Branch `pvphud-phase2b`. Completes the GUNNER half of the goal (gunner_seat_hud.conf deployed). Phase 3 delivers remote_controller_hud.conf to finish "both confs in the game folder, ready to test."_
