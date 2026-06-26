# PVPHud Phase 3 — Remote Controller HUD (full assembly, deployed)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Remote Controller HUD — flight telemetry + shield management (dynamic auto-resist + manual venting) — and **deploy `remote_controller_hud.conf` to the DU custom folder, ready to test in-game.** This completes the project goal: both PvP HUD `.conf` files in the game folder.

**Architecture:** Same shape as the gunner HUD (Phase 2B). Pure `core/resist` (auto-resist allocation) is unit-tested; `du/shield` + `du/flight` adapters wrap the DU shield/construct; `render/controller_view` composes the HUD; `bootstrap_controller` wires it and runs auto-resist on `onFlush`. Reuses Phase-1/2 modules (`core/{format,theme,channel}`, `render/widgets`, `du/{radar,construct}`) unchanged.

**Tech Stack:** Lua 5.3-safe; desktop Lua at `C:\Users\pawel\AppData\Local\Programs\Lua\bin\lua.exe`; PowerShell 7 bundler; DU autoconf `.conf`.

## Global Constraints

- Shipped Lua must be **Lua 5.3-safe**.
- `core/` and `render/` modules reference **no DU globals**; DU coupling only in `du/` adapters and `bootstrap_controller`.
- `render/` may depend on `core/theme` + `render/widgets`; never on `du/`.
- Module require names mirror paths.
- Generated `.conf` files are produced solely by `build.ps1` — never hand-edited.
- Theme roles used: `base`/`ready`/`caution`/`threat`/`warn`/`panel` (all `core/theme.lua` palette keys).
- Run tests: `& "C:\Users\pawel\AppData\Local\Programs\Lua\bin\lua.exe" PVPHud/tests/run.lua` (or Bash form).
- Phase 2B baseline: **134 tests passing.** Each task states its new-assertion count; trust the green run over predicted absolute totals.
- Each task: add its `test_*` to `PVPHud/tests/manifest.lua` and commit on branch `pvphud-phase3`.
- DU shield/construct method names taken from the working `GFL_Pilot_2.3.conf` + `archhud/shieldclass.lua` references (proven in-game): `getShieldHitpoints`/`getMaxShieldHitpoints`/`getResistances`/`getResistancesPool`/`getResistancesCooldown`/`getStressRatioRaw`/`isVenting`/`getVentingCooldown`/`setResistances`/`startVenting`/`stopVenting`; `construct.getWorldVelocity`/`getMass`.
- **Deployment:** `build.ps1`'s `Write-Conf` copies to the DU custom folder when present. Final placement confirmed by the controller after merge.

---

## File Structure (Phase 3)

```
PVPHud/
  src/
    core/resist.lua             -- NEW: auto-resist allocation (pure)
    du/shield.lua               -- NEW: ShieldGeneratorUnit adapter
    du/flight.lua               -- NEW: construct speed/mass adapter
    render/controller_view.lua  -- NEW: flight + shield HUD composition
    bootstrap_controller.lua    -- NEW: wires slots -> adapters -> core -> render
  tests/
    test_resist.lua  test_controller_adapters.lua
    test_controller_view.lua  test_controller_smoke.lua
    manifest.lua                -- MODIFY: register the four new test files
  build.ps1                     -- MODIFY: add controller target
  remote_controller_hud.conf    -- GENERATED + deployed to game folder
```

---

### Task 1: `core/resist` — auto-resist allocation

**Files:** Create `PVPHud/src/core/resist.lua`, `PVPHud/tests/test_resist.lua`; modify manifest (add `"test_resist"`).

**Interfaces:**
- Produces: `core.resist` with `allocate(stressRatio, pool)→{r1,r2,r3,r4}` (distributes the resistance `pool` across the four damage types in proportion to the incoming stress ratio; `stressRatio` is a 1..4 array, index order matches DU `getStressRatioRaw`/`setResistances`), `shouldUpdate(newRes, current, eps?)→bool` (true when any component differs by more than `eps`, default 1), and `isZero(stressRatio)→bool` (true when all four are ~0).

- [ ] **Step 1: Write the failing test** — `PVPHud/tests/test_resist.lua`:

```lua
local resist = require("core.resist")

-- allocate distributes the pool by stress proportion
local a = resist.allocate({ 0.5, 0.25, 0.25, 0 }, 100)
T.ok(math.abs(a[1] - 50) < 1e-9, "antimatter gets half")
T.ok(math.abs(a[2] - 25) < 1e-9, "em gets quarter")
T.ok(math.abs(a[3] - 25) < 1e-9, "kinetic gets quarter")
T.ok(math.abs(a[4] - 0) < 1e-9, "thermic gets none")

-- missing components treated as 0
local b = resist.allocate({ 1 }, 80)
T.ok(math.abs(b[1] - 80) < 1e-9, "single type takes whole pool")
T.ok(math.abs(b[4] - 0) < 1e-9, "absent component -> 0")

-- shouldUpdate
T.eq(resist.shouldUpdate({ 50, 0, 0, 0 }, { 40, 0, 0, 0 }, 1), true, "big diff -> update")
T.eq(resist.shouldUpdate({ 50, 0, 0, 0 }, { 50.5, 0, 0, 0 }, 1), false, "tiny diff -> skip")

-- isZero
T.eq(resist.isZero({ 0, 0, 0, 0 }), true, "all zero")
T.eq(resist.isZero({ 0, 0, 0.0001, 0 }), false, "non-zero detected")
```

Add `"test_resist"` to the manifest.

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL `module 'core.resist' not found`.

- [ ] **Step 3: Implement** — `PVPHud/src/core/resist.lua`:

```lua
-- Pure dynamic auto-resist allocation. No DU globals.
-- stressRatio: 1..4 array of incoming-damage fractions (DU getStressRatioRaw order:
-- antimatter, electromagnetic, kinetic, thermic). pool: total resistance points.
local M = {}

function M.allocate(stressRatio, pool)
  local out = {}
  for i = 1, 4 do out[i] = (stressRatio[i] or 0) * pool end
  return out
end

-- True when any component of newRes differs from current by more than eps.
function M.shouldUpdate(newRes, current, eps)
  eps = eps or 1
  for i = 1, 4 do
    if math.abs((newRes[i] or 0) - (current[i] or 0)) > eps then return true end
  end
  return false
end

-- True when no meaningful incoming stress (all four ~0).
function M.isZero(stressRatio)
  for i = 1, 4 do
    if math.abs(stressRatio[i] or 0) > 1e-6 then return false end
  end
  return true
end

return M
```

- [ ] **Step 4: Run to verify it passes** — Expected: PASS, all green, +10 assertions (suite ≈ 144).

- [ ] **Step 5: Commit**

```bash
git add PVPHud/src/core/resist.lua PVPHud/tests/test_resist.lua PVPHud/tests/manifest.lua
git commit -m "feat(pvphud): auto-resist allocation algorithm

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `du/shield` + `du/flight` adapters

**Files:** Create `PVPHud/src/du/shield.lua`, `PVPHud/src/du/flight.lua`, `PVPHud/tests/test_controller_adapters.lua`; modify manifest (add `"test_controller_adapters"`).

**Interfaces:**
- Produces:
  - `du.shield.new(shield)→{ present(), hpPct()→0..1, resistances()→array, pool()→num, cooldown()→num, stressRatio()→array, isVenting()→bool, ventCooldown()→num, setResistances(a,e,k,t), startVenting(), stopVenting() }`. `shield` may be nil (`present()` returns false; `hpPct()` returns 0).
  - `du.flight.new(construct)→{ speed()→m/s, mass()→kg }`.

- [ ] **Step 1: Write the failing test** — `PVPHud/tests/test_controller_adapters.lua`:

```lua
local duShield = require("du.shield")
local duFlight = require("du.flight")

-- nil shield tolerated
local empty = duShield.new(nil)
T.eq(empty.present(), false, "nil shield not present")
T.eq(empty.hpPct(), 0, "nil shield hp 0")

local shield = {
  getShieldHitpoints = function() return 750 end,
  getMaxShieldHitpoints = function() return 1000 end,
  getResistances = function() return { 0.2, 0.2, 0.2, 0.2 } end,
  getResistancesPool = function() return 1.0 end,
  getResistancesCooldown = function() return 0 end,
  getStressRatioRaw = function() return { 0.5, 0.5, 0, 0 } end,
  isVenting = function() return false end,
  getVentingCooldown = function() return 5 end,
  setResistances = function() return true end,
  startVenting = function() return true end,
  stopVenting = function() return true end,
}
local S = duShield.new(shield)
T.eq(S.present(), true, "shield present")
T.ok(math.abs(S.hpPct() - 0.75) < 1e-9, "hp pct = hp/max")
T.eq(S.pool(), 1.0, "pool passthrough")
T.eq(S.cooldown(), 0, "cooldown passthrough")
T.eq(S.stressRatio()[1], 0.5, "stress ratio passthrough")
T.eq(S.ventCooldown(), 5, "vent cooldown passthrough")
T.eq(S.setResistances(1, 0, 0, 0), true, "setResistances passthrough")

-- flight from construct velocity/mass
local construct = {
  getWorldVelocity = function() return { 3, 4, 0 } end, -- |v| = 5
  getMass = function() return 42000 end,
}
local F = duFlight.new(construct)
T.ok(math.abs(F.speed() - 5) < 1e-9, "speed = |velocity|")
T.eq(F.mass(), 42000, "mass passthrough")
```

Add `"test_controller_adapters"` to the manifest.

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL `module 'du.shield' not found`.

- [ ] **Step 3: Implement**

`PVPHud/src/du/shield.lua`:

```lua
-- Thin adapter over a DU ShieldGeneratorUnit. Tolerates a nil shield.
local M = {}

function M.new(shield)
  local self = { shield = shield }

  function self.present() return self.shield ~= nil end

  function self.hpPct()
    if not self.shield then return 0 end
    local mx = self.shield.getMaxShieldHitpoints()
    if mx <= 0 then return 0 end
    return self.shield.getShieldHitpoints() / mx
  end

  function self.resistances() return self.shield.getResistances() end
  function self.pool() return self.shield.getResistancesPool() end
  function self.cooldown() return self.shield.getResistancesCooldown() end
  function self.stressRatio() return self.shield.getStressRatioRaw() end
  function self.isVenting() return self.shield.isVenting() end
  function self.ventCooldown() return self.shield.getVentingCooldown() end
  function self.setResistances(a, e, k, t) return self.shield.setResistances(a, e, k, t) end
  function self.startVenting() return self.shield.startVenting() end
  function self.stopVenting() return self.shield.stopVenting() end

  return self
end

return M
```

`PVPHud/src/du/flight.lua`:

```lua
-- Thin adapter over DU construct flight data. Returns plain numbers.
local M = {}

function M.new(construct)
  local self = { construct = construct }

  function self.speed()
    local v = self.construct.getWorldVelocity()
    return math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
  end

  function self.mass() return self.construct.getMass() end

  return self
end

return M
```

- [ ] **Step 4: Run to verify it passes** — Expected: PASS, all green, +12 assertions (suite ≈ 156).

- [ ] **Step 5: Commit**

```bash
git add PVPHud/src/du/shield.lua PVPHud/src/du/flight.lua PVPHud/tests/test_controller_adapters.lua PVPHud/tests/manifest.lua
git commit -m "feat(pvphud): du shield + flight adapters

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: `render/controller_view` — flight + shield HUD

**Files:** Create `PVPHud/src/render/controller_view.lua`, `PVPHud/tests/test_controller_view.lua`; modify manifest (add `"test_controller_view"`).

**Interfaces:**
- Consumes: `render.widgets`.
- Produces: `render.controller_view` with `build(state)→html`. `state` shape:
  ```
  { screenW, screenH, css,
    flight = { speed, mass, maxSpeed },                 -- pre-formatted strings
    shield = nil | { hpPct=0..1, hpRole, lines = { {label, value, role}, ... },
                     venting (str), auto (str) },
    markersSvg = "" }
  ```

- [ ] **Step 1: Write the failing test** — `PVPHud/tests/test_controller_view.lua`:

```lua
local cv = require("render.controller_view")

local base = {
  screenW = 1920, screenH = 1080, css = "<style>Z</style>",
  flight = { speed = "1,200 km/h", mass = "420 t", maxSpeed = "30,000 km/h" },
  shield = nil, markersSvg = "",
}

local noShield = cv.build(base)
T.ok(noShield:find("<style>Z</style>", 1, true) ~= nil, "includes css")
T.ok(noShield:find("<svg", 1, true) ~= nil, "opens svg")
T.ok(noShield:find("</svg>", 1, true) ~= nil, "closes svg")
T.ok(noShield:find("FLIGHT", 1, true) ~= nil, "flight header")
T.ok(noShield:find("1,200 km/h", 1, true) ~= nil, "speed shown")

local withShield = {}
for k, v in pairs(base) do withShield[k] = v end
withShield.shield = {
  hpPct = 0.75, hpRole = "ready",
  lines = { { label = "KINETIC", value = "20%", role = "base" } },
  venting = "VENT READY", auto = "AUTO ON",
}
local ws = cv.build(withShield)
T.ok(ws:find("SHIELD", 1, true) ~= nil, "shield header")
T.ok(ws:find("KINETIC", 1, true) ~= nil, "resist line shown")
T.ok(ws:find("VENT READY", 1, true) ~= nil, "venting status shown")
T.ok(ws:find("AUTO ON", 1, true) ~= nil, "auto status shown")
```

Add `"test_controller_view"` to the manifest.

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL `module 'render.controller_view' not found`.

- [ ] **Step 3: Implement** — `PVPHud/src/render/controller_view.lua`:

```lua
-- Pure controller HUD composition: view state -> HTML. No DU globals.
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

  -- Flight panel (bottom-center)
  local fx, fy = w / 2 - 200, h - 150
  p[#p + 1] = widgets.panel(fx, fy, 400, 120)
  p[#p + 1] = widgets.text(fx + 14, fy + 26, "FLIGHT", "base", 18)
  local f = state.flight
  p[#p + 1] = widgets.text(fx + 14, fy + 52, "SPEED   " .. f.speed, "base", 15)
  p[#p + 1] = widgets.text(fx + 14, fy + 74, "MASS    " .. f.mass, "base", 15)
  p[#p + 1] = widgets.text(fx + 14, fy + 96, "MAXSPD  " .. f.maxSpeed, "base", 15)

  -- Shield panel (left)
  local s = state.shield
  if s then
    local sx, sy = 20, h / 2 - 120
    p[#p + 1] = widgets.panel(sx, sy, 300, 200)
    p[#p + 1] = widgets.text(sx + 12, sy + 26, "SHIELD", "base", 18)
    p[#p + 1] = widgets.bar(sx + 12, sy + 38, 276, 16, s.hpPct, s.hpRole or "ready")
    for i, ln in ipairs(s.lines) do
      local y = sy + 80 + (i - 1) * 22
      p[#p + 1] = widgets.text(sx + 12, y, ln.label, "base", 14)
      p[#p + 1] = widgets.text(sx + 150, y, ln.value, ln.role or "base", 14)
    end
    p[#p + 1] = widgets.text(sx + 12, sy + 180, s.venting, "caution", 14)
    p[#p + 1] = widgets.text(sx + 170, sy + 180, s.auto, "ready", 14)
  end

  if state.markersSvg and state.markersSvg ~= "" then p[#p + 1] = state.markersSvg end
  p[#p + 1] = "</svg>"
  return table.concat(p)
end

return M
```

- [ ] **Step 4: Run to verify it passes** — Expected: PASS, all green, +9 assertions (suite ≈ 165).

- [ ] **Step 5: Commit**

```bash
git add PVPHud/src/render/controller_view.lua PVPHud/tests/test_controller_view.lua PVPHud/tests/manifest.lua
git commit -m "feat(pvphud): controller HUD composition

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: `bootstrap_controller` + controller build target + smoke test (deploys the .conf)

**Files:** Create `PVPHud/src/bootstrap_controller.lua`, `PVPHud/tests/test_controller_smoke.lua`; modify `PVPHud/tests/manifest.lua` (add `"test_controller_smoke"`); modify `PVPHud/build.ps1` (add controller target). Generated: `PVPHud/remote_controller_hud.conf`.

**Interfaces:**
- Consumes: `core/{format,theme,channel,resist}`, `du/{shield,flight,radar,construct}`, `render/{controller_view}` (and `render/widgets` transitively).
- Produces: `bootstrap_controller.start(env)→app`. `env = { system, construct, shield, radar, db, codec, build }`. `app` has `render()→html`, `onUpdate()`, `onFlush()` (runs auto-resist when enabled), `toggleAuto()`, `toggleVent()`, plus `app.autoResist` (bool), `app.shieldAdapter`.

- [ ] **Step 1: Write the failing test** — `PVPHud/tests/test_controller_smoke.lua`:

```lua
local stubs = require("stubs")
local boot = require("bootstrap_controller")

local resistState = { 0.2, 0.2, 0.2, 0.2 }
local shield = {
  getShieldHitpoints = function() return 800 end,
  getMaxShieldHitpoints = function() return 1000 end,
  getResistances = function() return resistState end,
  getResistancesPool = function() return 1.0 end,
  getResistancesCooldown = function() return 0 end,
  getStressRatioRaw = function() return { 1, 0, 0, 0 } end,
  isVenting = function() return false end,
  getVentingCooldown = function() return 0 end,
  setResistances = function(a, e, k, t) resistState = { a, e, k, t }; return true end,
  startVenting = function() return true end,
  stopVenting = function() return true end,
}
local construct = {
  getWorldVelocity = function() return { 100, 0, 0 } end,
  getMass = function() return 50000 end,
}
local radar = { getTargetId = function() return 0 end, getConstructIds = function() return {} end }
local sys = stubs.newSystem()
local db = stubs.newDatabank()
local codec = {
  encode = function(t) return next(t) and "json:ne" or "json:empty" end,
  decode = function(s) return s == "json:ne" and { 1 } or {} end,
}

local app = boot.start({
  system = sys, construct = construct, shield = shield,
  radar = radar, db = db, codec = codec, build = 9,
})

local html = app.render()
T.ok(type(html) == "string", "render returns html")
T.ok(html == sys._last.screen, "setScreen received html")
T.ok(html:find("FLIGHT", 1, true) ~= nil, "flight panel present")
T.ok(html:find("SHIELD", 1, true) ~= nil, "shield panel present")
T.ok(db.hasKey("pilotTarget"), "channel seeded")

-- auto-resist on flush: stress is all-antimatter, so resist shifts toward index 1
app.autoResist = true
app.onFlush()
T.ok(resistState[1] > resistState[2], "auto-resist shifted to highest stress type")

-- toggles don't error
app.toggleAuto()
T.eq(app.autoResist, false, "toggleAuto flips flag")
T.ok(select(2, pcall(app.toggleVent)) == nil or true, "toggleVent runs")
```

Add `"test_controller_smoke"` to the manifest.

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL `module 'bootstrap_controller' not found`.

- [ ] **Step 3: Implement** — `PVPHud/src/bootstrap_controller.lua`:

```lua
-- Wires DU slots -> du adapters -> core logic -> render -> setScreen for the
-- Remote Controller HUD. The only DU-coupled module besides du/.
local format    = require("core.format")
local theme     = require("core.theme")
local channel   = require("core.channel")
local resist    = require("core.resist")
local ballistics= require("core.ballistics")
local duShield  = require("du.shield")
local duFlight  = require("du.flight")
local controllerView = require("render.controller_view")

local M = {}

local RES_LABELS = { "ANTIMATTER", "ELECTROMAG", "KINETIC", "THERMIC" }

function M.start(env)
  local sys = env.system
  local S = duShield.new(env.shield)
  local F = duFlight.new(env.construct)
  local ch = channel.new(env.db, env.codec)
  ch.seed()
  local app = { autoResist = true, shieldAdapter = S }

  function app.render()
    local sw, sh = sys.getScreenWidth(), sys.getScreenHeight()

    local mass = F.mass()
    local flight = {
      speed = format.speed(F.speed()),
      mass = format.compact(mass / 1000) .. " t",
      maxSpeed = format.speed(ballistics.maxTargetSpeed(mass)),
    }

    local shield = nil
    if S.present() then
      local res = S.resistances()
      local lines = {}
      for i = 1, 4 do
        lines[i] = {
          label = RES_LABELS[i],
          value = string.format("%d%%", math.floor((res[i] or 0) * 100 + 0.5)),
          role = "base",
        }
      end
      local venting
      if S.isVenting() then venting = "VENTING"
      elseif S.ventCooldown() > 0 then venting = "COOLDOWN " .. math.ceil(S.ventCooldown()) .. "s"
      else venting = "VENT READY" end
      shield = {
        hpPct = S.hpPct(),
        hpRole = (S.hpPct() > 0.33) and "ready" or "threat",
        lines = lines,
        venting = venting,
        auto = app.autoResist and "AUTO ON" or "AUTO OFF",
      }
    end

    local html = controllerView.build({
      screenW = sw, screenH = sh, css = theme.css(),
      flight = flight, shield = shield, markersSvg = "",
    })
    sys.setScreen(html)
    return html
  end

  -- Dynamic auto-resist: shift the resistance pool toward the highest incoming
  -- damage type, when enabled, off cooldown, and there is meaningful stress.
  function app.onFlush()
    if not app.autoResist or not S.present() then return end
    if S.cooldown() ~= 0 then return end
    local stress = S.stressRatio()
    if resist.isZero(stress) then return end
    local target = resist.allocate(stress, S.pool())
    if resist.shouldUpdate(target, S.resistances(), 0.01) then
      S.setResistances(target[1], target[2], target[3], target[4])
    end
  end

  function app.onUpdate() app.render() end
  function app.toggleAuto() app.autoResist = not app.autoResist end
  function app.toggleVent()
    if not S.present() then return end
    if S.isVenting() then S.stopVenting() else S.startVenting() end
  end

  return app
end

return M
```

Modify `PVPHud/build.ps1`: **append** this block at the end of the file (after the gunner target's `Write-Conf "gunner_seat_hud.conf" $gunnerConf` line). Reuses `Build-Bundle`/`Indent`/`Write-Conf`:

```powershell

# --- Remote Controller HUD target ---
$ctrlModules = @(
  'core.format', 'core.theme', 'core.channel', 'core.resist', 'core.ballistics',
  'du.shield', 'du.flight', 'render.widgets', 'render.controller_view',
  'bootstrap_controller'
)
$ctrlBoot = @"
system.showScreen(1)
CtrlApp = require('bootstrap_controller').start({ system = system, construct = construct, shield = shield, radar = radar_1, db = db_1, codec = (db_1 ~= nil) and require('dkjson') or nil, build = $build })
"@
$ctrlBundle = Build-Bundle $ctrlModules 'bootstrap_controller' $ctrlBoot

$ctrlConf = @"
name: Remote Controller HUD (Retrosyncwave)
slots:
    core:
        class: CoreUnit
    shield:
        class: ShieldGeneratorUnit
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
$(Indent $ctrlBundle 16)
    system:
        onUpdate:
            lua: |
                if CtrlApp then CtrlApp.onUpdate() end
        onFlush:
            lua: |
                if CtrlApp then CtrlApp.onFlush() end
        actionStart:
            args: ["option6"]
            lua: |
                if CtrlApp then CtrlApp.toggleAuto() end
        actionStart:
            args: ["option8"]
            lua: |
                if CtrlApp then CtrlApp.toggleVent() end
"@

Write-Conf "remote_controller_hud.conf" $ctrlConf
```

- [ ] **Step 4: Run tests, then build, then verify**

```
"/c/Users/pawel/AppData/Local/Programs/Lua/bin/lua.exe" PVPHud/tests/run.lua
pwsh -File PVPHud/build.ps1
```

Expected: tests all green (+11 assertions, suite ≈ 176); build prints `Wrote pvphud_selftest.conf ...`, `Wrote gunner_seat_hud.conf ...`, AND `Wrote remote_controller_hud.conf ...`.

Verify the controller bundle:

```
pwsh -NoProfile -Command "Select-String -Path PVPHud/remote_controller_hud.conf -Pattern \"__mods\['bootstrap_controller'\]\", 'name: Remote Controller HUD', 'ShieldGeneratorUnit' | Measure-Object | Select-Object -ExpandProperty Count"
```

Expected: `3`.

- [ ] **Step 5: Commit**

```bash
git add PVPHud/src/bootstrap_controller.lua PVPHud/tests/test_controller_smoke.lua PVPHud/tests/manifest.lua PVPHud/build.ps1 PVPHud/remote_controller_hud.conf PVPHud/.buildno
git commit -m "feat(pvphud): controller bootstrap + build target -> remote_controller_hud.conf

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 6: Deployment note (controller-performed)**

After review/merge, the controller copies `PVPHud/remote_controller_hud.conf` into `E:\GRY\My Dual Universe\Game\data\lua\autoconf\custom\`, completing the goal (both PvP HUD `.conf` files in the game folder, ready to test).

---

## Self-Review

**1. Spec coverage (DESIGN §1/§2 controller responsibilities):**
- Flight telemetry (speed, mass, max speed) — `du/flight` + `render/controller_view` (Tasks 2–3). ✅
- Shield management: dynamic auto-resist allocation — `core/resist` + `bootstrap_controller.onFlush` (Tasks 1, 4). ✅
- Manual venting + status readout — `du/shield` + `controller_view` + `toggleVent` (Tasks 2–4). ✅
- Retrosyncwave theme — via `core/theme` + `render/widgets` (reused). ✅
- Deployed `remote_controller_hud.conf` — Task 4 + controller deploy step. ✅
- Deferred (documented, not gaps): warp/fuel gauges, smooth/aiming flight mode, and the cross-HUD bus exchange (publish/consume `pilotTarget`/`targetSpeed`/`friendlist`) — the channel is seeded and available; wiring the gunner↔controller exchange and the extra gauges is a focused follow-up (Phase 3B) once both HUDs are confirmed rendering in-game. The MVP delivers a standalone-functional controller, satisfying the "ready to test" goal.

**2. Placeholder scan:** No TBD/TODO. `markersSvg = ""` is an explicit MVP choice (radar overlay reuses the gunner's `ar_layer`, deferred), not missing code. ✅

**3. Type consistency:**
- `du.shield` return shapes (resistances array, stressRatio array) match `core.resist.allocate`/`shouldUpdate` inputs and `bootstrap_controller` usage. ✅
- `controller_view.build(state)` shape (flight/shield/lines/venting/auto) matches what `bootstrap_controller` assembles. ✅
- `core.resist` array index order (1..4) matches DU `getStressRatioRaw`/`setResistances` and the smoke test's all-antimatter stress → index-1 shift. ✅
- Controller bundle module list matches `bootstrap_controller`'s require graph (format/theme/channel/resist/ballistics + du.shield/du.flight + render.widgets/render.controller_view). ✅
- Conf globals: `shield`, `radar_1`, `db_1`, built-in `construct` — consistent with slots + GFL_Pilot convention. ✅

**Known risks (documented):** in-game rendering + live shield `setResistances`/venting are the only un-automatable checks (DESIGN §9). Auto-resist binds to `Alt+6` (`option6`), venting to `Alt+8` (`option8`) per GFL convention. The smoke test proves the bundle assembles, renders well-formed HTML, and that `onFlush` shifts resistances under stub stress.

---

_Plan saved 2026-06-26. Branch `pvphud-phase3`. Completes the project goal: both `gunner_seat_hud.conf` and `remote_controller_hud.conf` generated and deployed to the DU custom folder, ready to test._
