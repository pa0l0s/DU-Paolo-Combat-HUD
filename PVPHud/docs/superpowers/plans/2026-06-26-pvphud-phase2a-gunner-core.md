# PVPHud Phase 2A — Gunner Targeting & Telemetry Core

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure, unit-tested algorithm modules the Gunner Seat HUD needs — weapon ballistics, damage telemetry, threat classification, and AR position tracking — and fix the carried-forward `channel.getJson` shared-default hazard.

**Architecture:** Each module is a pure `core/` unit with no DU globals, depending only on plain tables passed in (DESIGN §4 DIP). They are validated entirely on desktop Lua so the un-testable DU assembly (Phase 2B: `du/` adapters + `render/` + `bootstrap_gunner` + `.conf`) consumes a proven core.

**Tech Stack:** Lua 5.3-safe; desktop Lua at `C:\Users\pawel\AppData\Local\Programs\Lua\bin\lua.exe`; existing manifest-driven test harness from Phase 1.

## Global Constraints

- Shipped Lua must be **Lua 5.3-safe**.
- `core/` modules must **not** reference DU globals — only plain tables/values passed in.
- Module require names mirror paths: `src/core/ballistics.lua` → `require("core.ballistics")`.
- Each task ends with a green suite. Run: `& "C:\Users\pawel\AppData\Local\Programs\Lua\bin\lua.exe" PVPHud/tests/run.lua` (or Bash: `"/c/Users/pawel/AppData/Local/Programs/Lua/bin/lua.exe" PVPHud/tests/run.lua`).
- Theme roles referenced by these modules: `ready` / `caution` / `threat` / `dim` (these are keys in `core/theme.lua`'s palette).
- Phase 1 baseline: suite reports **28 passed**. Each task below states the new expected total.
- Each task: add its `test_*` name to `PVPHud/tests/manifest.lua` and commit on branch `pvphud-phase2` with the shown message.
- Approx-float assertions use `T.ok(math.abs(a-b) < eps, msg)` (the harness `T.eq` is exact-equality only).

---

## File Structure (Phase 2A)

```
PVPHud/
  src/core/
    channel.lua    -- MODIFY: getJson returns a fresh copy of the default
    ballistics.lua -- NEW: range/angular/hit color bands, spread, max target speed
    dps.lua        -- NEW: rolling damage in/out buffers, stats, series
    threat.lua     -- NEW: construct friend/enemy/dead classification
    tracking.lua   -- NEW: AR position cache + velocity extrapolation + dead cores
  tests/
    test_channel.lua   -- MODIFY: add no-shared-default assertions
    test_ballistics.lua -- NEW
    test_dps.lua        -- NEW
    test_threat.lua     -- NEW
    test_tracking.lua   -- NEW
    manifest.lua        -- MODIFY: register the four new test files
```

---

### Task 1: Fix `channel.getJson` shared mutable default

**Files:**
- Modify: `PVPHud/src/core/channel.lua`
- Modify: `PVPHud/tests/test_channel.lua`

**Interfaces:**
- Consumes: existing `core.channel` from Phase 1.
- Produces: `getJson(key)` now returns a **fresh table** every call when falling back to the schema default (never the shared `spec.default` instance).

- [ ] **Step 1: Write the failing test** — append to `PVPHud/tests/test_channel.lua`:

```lua
-- getJson must never hand out the shared schema default by reference.
local a = ch.getJson("deadCores")   -- key absent -> default path
local b = ch.getJson("deadCores")
T.ok(a ~= b, "getJson returns distinct tables per call")
a["x"] = 1
T.eq(#channel.schema.deadCores.default, 0, "schema default not mutated by caller")
T.eq(next(ch.getJson("deadCores")), nil, "later getJson still empty after caller mutation")
```

- [ ] **Step 2: Run to verify it fails**

Run: `"/c/Users/pawel/AppData/Local/Programs/Lua/bin/lua.exe" PVPHud/tests/run.lua`
Expected: FAIL — `getJson returns distinct tables per call` (currently the same `spec.default` reference is returned twice).

- [ ] **Step 3: Implement** — in `PVPHud/src/core/channel.lua`, add a module-local copy helper above `M.new` and use it in `getJson`. Replace the existing `getJson` body:

Add near the top (after `local M = {}` / `M.schema`):

```lua
-- Shallow copy of a schema default so callers never mutate the shared instance.
local function copyDefault(default)
  local c = {}
  for k, v in pairs(default) do c[k] = v end
  return c
end
```

Replace the whole `function self.getJson(key) ... end` with:

```lua
  function self.getJson(key)
    local spec = M.schema[key]
    if not db or not codec or not db.hasKey(key) then
      return copyDefault(spec.default)
    end
    return codec.decode(db.getStringValue(key)) or copyDefault(spec.default)
  end
```

- [ ] **Step 4: Run to verify it passes**

Run: `"/c/Users/pawel/AppData/Local/Programs/Lua/bin/lua.exe" PVPHud/tests/run.lua`
Expected: PASS — `31 passed, 0 failed` (28 + 3 new channel assertions).

- [ ] **Step 5: Commit**

```bash
git add PVPHud/src/core/channel.lua PVPHud/tests/test_channel.lua
git commit -m "fix(pvphud): channel.getJson returns fresh default copy

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `core/ballistics` — weapon range/angular/hit math

**Files:**
- Create: `PVPHud/src/core/ballistics.lua`
- Create: `PVPHud/tests/test_ballistics.lua`
- Modify: `PVPHud/tests/manifest.lua` (add `"test_ballistics"`)

**Interfaces:**
- Produces: `core.ballistics` with `rangeBand(distance, optimal, spread)→role`, `spread(maxDistance, optimalDistance)→number`, `angularBand(angular, optimalTracking)→role`, `hitBand(hitPct)→role`, `maxTargetSpeed(massKg)→mps`. `role` ∈ {"ready","caution","threat"}.

- [ ] **Step 1: Write the failing test** — `PVPHud/tests/test_ballistics.lua`:

```lua
local b = require("core.ballistics")

-- rangeBand: optimal=1000, spread=500
T.eq(b.rangeBand(900, 1000, 500), "ready", "in optimal")
T.eq(b.rangeBand(1000, 1000, 500), "ready", "at optimal boundary")
T.eq(b.rangeBand(1400, 1000, 500), "caution", "within spread")
T.eq(b.rangeBand(1600, 1000, 500), "threat", "beyond spread")

T.eq(b.spread(3000, 1000), 1000, "spread is half the optimal->max gap")

-- angularBand: tracking=20 deg/s
T.eq(b.angularBand(15, 20), "ready", "tracking ok")
T.eq(b.angularBand(35, 20), "caution", "within 2x tracking")
T.eq(b.angularBand(50, 20), "threat", "exceeds 2x tracking")
T.eq(b.angularBand(10, 0), "threat", "no tracking -> threat")

T.eq(b.hitBand(80), "ready", "high hit%")
T.eq(b.hitBand(50), "caution", "mid hit%")
T.eq(b.hitBand(10), "threat", "low hit%")

-- maxTargetSpeed: clamps to 50000 km/h at/below 10000 kg, to 20000 km/h when very heavy
T.ok(math.abs(b.maxTargetSpeed(10000) - 50000/3.6) < 1e-6, "light cap = 50000 km/h")
T.ok(math.abs(b.maxTargetSpeed(1e12) - 20000/3.6) < 1e-3, "very heavy cap = 20000 km/h")
T.ok(b.maxTargetSpeed(500000) < b.maxTargetSpeed(50000), "heavier is slower")
```

Add `"test_ballistics"` to `PVPHud/tests/manifest.lua` (append to the returned list).

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `module 'core.ballistics' not found`.

- [ ] **Step 3: Implement** — `PVPHud/src/core/ballistics.lua`:

```lua
-- Pure PvP weapon math. No DU globals.
local M = {}

-- Distance color band vs a weapon's optimal range and spread.
function M.rangeBand(distance, optimal, spread)
  if distance <= optimal then return "ready"
  elseif distance <= optimal + spread then return "caution"
  else return "threat" end
end

-- Half the gap between optimal and max distance.
function M.spread(maxDistance, optimalDistance)
  return (maxDistance - optimalDistance) / 2
end

-- Angular-speed (deg/s) band vs a weapon's optimal tracking.
function M.angularBand(angular, optimalTracking)
  if optimalTracking <= 0 then return "threat" end
  if angular <= optimalTracking then return "ready"
  elseif angular <= optimalTracking * 2 then return "caution"
  else return "threat" end
end

-- Hit-probability (0..100) band.
function M.hitBand(hitPct)
  if hitPct >= 70 then return "ready"
  elseif hitPct >= 30 then return "caution"
  else return "threat" end
end

-- Max attainable speed (m/s) for a target of given mass (kg).
-- DU PvP speed-vs-mass curve; clamped between 20000 and 50000 km/h.
function M.maxTargetSpeed(massKg)
  local hi = 50000 / 3.6
  local lo = 20000 / 3.6
  local v = hi - 10713 * (massKg - 10000) / (853926 + massKg - 10000)
  return math.max(math.min(hi, v), lo)
end

return M
```

- [ ] **Step 4: Run to verify it passes**

Expected: PASS — `45 passed, 0 failed` (31 + 14 new).

- [ ] **Step 5: Commit**

```bash
git add PVPHud/src/core/ballistics.lua PVPHud/tests/test_ballistics.lua PVPHud/tests/manifest.lua
git commit -m "feat(pvphud): ballistics range/angular/hit bands + max target speed

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: `core/dps` — rolling damage telemetry

**Files:**
- Create: `PVPHud/src/core/dps.lua`
- Create: `PVPHud/tests/test_dps.lua`
- Modify: `PVPHud/tests/manifest.lua` (add `"test_dps"`)

**Interfaces:**
- Produces: `core.dps` with `new(opts)→inst`. `opts = { buckets=N (default 90), window=W (default 10) }`. `inst` fields/methods: `recordReceived(amount)`, `recordHit(targetId, damage)`, `recordMiss(targetId)`, `tick()`, `accuracy()→0..1`, `series(which)→{numbers}` (`which`="received"|"caused"), and readable fields `shotsFired`, `shotsHit`, `damageDealt`, `damageById[id]`, `peakDps`.

- [ ] **Step 1: Write the failing test** — `PVPHud/tests/test_dps.lua`:

```lua
local dps = require("core.dps")

local d = dps.new({ buckets = 5, window = 2 })
T.eq(#d.series("caused"), 5, "buffer initialized to N buckets")
T.eq(d.accuracy(), 0, "accuracy 0 before any shots")

d.recordHit(42, 100)
d.recordHit(42, 50)
d.recordMiss(42)
T.eq(d.shotsFired, 3, "fired counts hits + misses")
T.eq(d.shotsHit, 2, "hits counted")
T.eq(d.damageDealt, 150, "total damage")
T.eq(d.damageById[42], 150, "per-target damage")
T.ok(math.abs(d.accuracy() - 2/3) < 1e-9, "accuracy = hits/fired")

-- current caused bucket holds 150 before any tick
local caused = d.series("caused")
T.eq(caused[#caused], 150, "damage lands in latest bucket")

d.recordReceived(80)
local rec = d.series("received")
T.eq(rec[#rec], 80, "received lands in latest bucket")

-- tick rolls: latest bucket becomes 0, length preserved, peak updated
d.tick()
T.eq(#d.series("caused"), 5, "length preserved after tick")
T.eq(d.series("caused")[5], 0, "new latest bucket is empty")
T.ok(d.peakDps > 0, "peak dps updated from window")
```

Add `"test_dps"` to the manifest.

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `module 'core.dps' not found`.

- [ ] **Step 3: Implement** — `PVPHud/src/core/dps.lua`:

```lua
-- Pure damage telemetry: rolling in/out buffers, stats, graph series.
-- Stateful instance; no DU globals.
local M = {}

function M.new(opts)
  opts = opts or {}
  local n = opts.buckets or 90
  local self = {
    received = {}, caused = {},
    shotsFired = 0, shotsHit = 0,
    damageDealt = 0, damageById = {},
    peakDps = 0, _window = opts.window or 10,
  }
  for i = 1, n do self.received[i] = 0; self.caused[i] = 0 end

  function self.recordReceived(amount)
    self.received[#self.received] = self.received[#self.received] + amount
  end

  function self.recordHit(targetId, damage)
    self.caused[#self.caused] = self.caused[#self.caused] + damage
    self.damageDealt = self.damageDealt + damage
    self.damageById[targetId] = (self.damageById[targetId] or 0) + damage
    self.shotsHit = self.shotsHit + 1
    self.shotsFired = self.shotsFired + 1
  end

  function self.recordMiss(targetId)
    self.shotsFired = self.shotsFired + 1
  end

  -- Update peak from the trailing window, then roll both buffers by one.
  function self.tick()
    local w = math.min(self._window, #self.caused)
    local sum = 0
    for i = #self.caused, #self.caused - w + 1, -1 do sum = sum + self.caused[i] end
    local windowDps = sum / w
    if windowDps > self.peakDps then self.peakDps = windowDps end
    table.remove(self.received, 1); self.received[#self.received + 1] = 0
    table.remove(self.caused, 1);   self.caused[#self.caused + 1] = 0
  end

  function self.accuracy()
    if self.shotsFired == 0 then return 0 end
    return self.shotsHit / self.shotsFired
  end

  function self.series(which)
    local src = (which == "received") and self.received or self.caused
    local out = {}
    for i = 1, #src do out[i] = src[i] end
    return out
  end

  return self
end

return M
```

- [ ] **Step 4: Run to verify it passes**

Expected: PASS — `58 passed, 0 failed` (45 + 13 new).

- [ ] **Step 5: Commit**

```bash
git add PVPHud/src/core/dps.lua PVPHud/tests/test_dps.lua PVPHud/tests/manifest.lua
git commit -m "feat(pvphud): dps rolling damage telemetry

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: `core/threat` — construct classification

**Files:**
- Create: `PVPHud/src/core/threat.lua`
- Create: `PVPHud/tests/test_threat.lua`
- Modify: `PVPHud/tests/manifest.lua` (add `"test_threat"`)

**Interfaces:**
- Produces: `core.threat` with `classify(info)→{kind, role, identified}` where `info = {threatRate, transponder, friend, abandoned, identified}` and `kind` ∈ {"dead","friend","enemy"}, `role` ∈ {"dim","ready","threat"}; and `markerRole(kind)→role`.

- [ ] **Step 1: Write the failing test** — `PVPHud/tests/test_threat.lua`:

```lua
local threat = require("core.threat")

local dead = threat.classify({ abandoned = true, friend = true, identified = true })
T.eq(dead.kind, "dead", "abandoned overrides friend")
T.eq(dead.role, "dim", "dead uses dim role")

local fr = threat.classify({ friend = true })
T.eq(fr.kind, "friend", "friend by friendlist")
T.eq(fr.role, "ready", "friend uses ready role")

local tr = threat.classify({ transponder = true })
T.eq(tr.kind, "friend", "transponder match => friend")

local en = threat.classify({ threatRate = 4 })
T.eq(en.kind, "enemy", "default is enemy")
T.eq(en.role, "threat", "enemy uses threat role")
T.eq(en.identified, false, "identified defaults false")

T.eq(threat.markerRole("friend"), "ready", "markerRole friend")
T.eq(threat.markerRole("dead"), "dim", "markerRole dead")
T.eq(threat.markerRole("enemy"), "threat", "markerRole enemy")
```

Add `"test_threat"` to the manifest.

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `module 'core.threat' not found`.

- [ ] **Step 3: Implement** — `PVPHud/src/core/threat.lua`:

```lua
-- Pure construct classification for radar/AR. No DU globals.
local M = {}

-- info = { threatRate, transponder, friend, abandoned, identified }
function M.classify(info)
  if info.abandoned then
    return { kind = "dead", role = "dim", identified = info.identified or false }
  end
  if info.friend or info.transponder then
    return { kind = "friend", role = "ready", identified = info.identified or false }
  end
  return { kind = "enemy", role = "threat", identified = info.identified or false }
end

-- Theme role for a classified kind (AR marker color).
function M.markerRole(kind)
  if kind == "friend" then return "ready"
  elseif kind == "dead" then return "dim"
  else return "threat" end
end

return M
```

- [ ] **Step 4: Run to verify it passes**

Expected: PASS — `68 passed, 0 failed` (58 + 10 new).

- [ ] **Step 5: Commit**

```bash
git add PVPHud/src/core/threat.lua PVPHud/tests/test_threat.lua PVPHud/tests/manifest.lua
git commit -m "feat(pvphud): threat classification

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: `core/tracking` — AR position memory

**Files:**
- Create: `PVPHud/src/core/tracking.lua`
- Create: `PVPHud/tests/test_tracking.lua`
- Modify: `PVPHud/tests/manifest.lua` (add `"test_tracking"`)

**Interfaces:**
- Produces: `core.tracking` with `new()→inst`. Positions are plain `{x,y,z}` tables (no DU `vec3`). `inst` methods: `update(id, pos, t)`, `predict(id, t)→{x,y,z}|nil` (extrapolates by last velocity when stale), `forget(id)`, `markDead(id, pos)`, `deadCores()→{[id]={x,y,z}}`, `clearDead()`.

- [ ] **Step 1: Write the failing test** — `PVPHud/tests/test_tracking.lua`:

```lua
local tracking = require("core.tracking")

local tk = tracking.new()
T.eq(tk.predict(7, 0), nil, "unknown id predicts nil")

-- single observation: no velocity yet -> returns the observed position
tk.update(7, { x = 0, y = 0, z = 0 }, 0)
local p0 = tk.predict(7, 5)
T.ok(p0 ~= nil and p0.x == 0 and p0.y == 0 and p0.z == 0, "no velocity -> static position")

-- second observation establishes velocity (10 m/s on x)
tk.update(7, { x = 10, y = 0, z = 0 }, 1)
local p1 = tk.predict(7, 2)
T.ok(math.abs(p1.x - 20) < 1e-9, "extrapolates one second of velocity")
T.ok(math.abs(p1.y) < 1e-9 and math.abs(p1.z) < 1e-9, "no drift off-axis")

tk.forget(7)
T.eq(tk.predict(7, 3), nil, "forgotten id predicts nil")

-- dead-core memory
tk.markDead(999, { x = 1, y = 2, z = 3 })
local dc = tk.deadCores()
T.ok(dc[999] ~= nil and dc[999].y == 2, "dead core remembered")
tk.clearDead()
T.eq(next(tk.deadCores()), nil, "dead cores cleared")
```

Add `"test_tracking"` to the manifest.

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `module 'core.tracking' not found`.

- [ ] **Step 3: Implement** — `PVPHud/src/core/tracking.lua`:

```lua
-- Pure AR position memory: caches world positions, estimates velocity,
-- extrapolates when contact is lost, remembers dead-core positions.
-- Plain {x,y,z} tables; no DU globals, no vec3 dependency.
local M = {}

local function sub(a, b) return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z } end
local function add(a, b) return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z } end
local function scale(a, s) return { x = a.x * s, y = a.y * s, z = a.z * s } end

function M.new()
  local self = { live = {}, dead = {} }

  function self.update(id, pos, t)
    local prev = self.live[id]
    local vel = prev and prev.vel or nil
    if prev then
      local dt = t - prev.t
      if dt > 0 then vel = scale(sub(pos, prev.pos), 1 / dt) end
    end
    self.live[id] = { pos = { x = pos.x, y = pos.y, z = pos.z }, t = t, vel = vel }
  end

  function self.predict(id, t)
    local e = self.live[id]
    if not e then return nil end
    if e.vel then return add(e.pos, scale(e.vel, t - e.t)) end
    return { x = e.pos.x, y = e.pos.y, z = e.pos.z }
  end

  function self.forget(id) self.live[id] = nil end

  function self.markDead(id, pos)
    self.dead[id] = { x = pos.x, y = pos.y, z = pos.z }
  end

  function self.deadCores()
    local out = {}
    for id, pos in pairs(self.dead) do out[id] = pos end
    return out
  end

  function self.clearDead() self.dead = {} end

  return self
end

return M
```

- [ ] **Step 4: Run to verify it passes**

Expected: PASS — `78 passed, 0 failed` (68 + 10 new).

- [ ] **Step 5: Commit**

```bash
git add PVPHud/src/core/tracking.lua PVPHud/tests/test_tracking.lua PVPHud/tests/manifest.lua
git commit -m "feat(pvphud): tracking AR position memory

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage (against DESIGN §5 algorithm list):**
- `ballistics` (optimal range, falloff/spread, angular vs tracking, hit-% color, mass→max-speed) — Task 2. ✅
- `dps` (rolling in/out buffers, peak DPS, series for graphing) — Task 3. ✅
- `threat` (friend/enemy/dead/identified) — Task 4. ✅
- `tracking` (position cache + velocity extrapolation + dead-core persistence) — Task 5. ✅
- `channel.getJson` defensive copy (carried-forward must-fix) — Task 1. ✅
- `render/` (widgets, ar_layer, gunner_view), `du/` adapters (radar, weapon, construct, databank), `bootstrap_gunner`, the gunner `.conf`, and in-game wiring — **deferred to Phase 2B.** Not a gap; the algorithm core is the testable half built first (stated in plan intro).

**2. Placeholder scan:** No TBD/TODO; every code step contains complete, runnable code. ✅

**3. Type consistency:**
- Theme roles used here (`ready`/`caution`/`threat`/`dim`) all exist in `core/theme.lua`'s palette (Phase 1). ✅
- `dps.new(opts)` option names (`buckets`, `window`) match between Task 3 test and implementation. ✅
- `tracking` position shape `{x,y,z}` consistent across `update`/`predict`/`markDead`/tests. ✅
- `threat.classify` return shape `{kind, role, identified}` matches its test. ✅
- Expected suite totals chain correctly: 28 → 31 → 45 → 58 → 68 → 78. ✅

**Phase 2B preview (next plan):** `du/radar`, `du/weapon`, `du/construct`, `du/databank` adapters (signatures taken from the working `GFL_Gunner_2.0.conf` reference: `weapon.getOptimalDistance/getMaxDistance/getOptimalTracking/getHitProbability/getStatus/getAmmoCount/getMaxAmmo/getClass`; `radar.getConstructIds/getTargetId/getThreatRateFrom/getConstructWorldPos/getConstructDistance/getConstructAngularSpeed/getConstructSpeed/getConstructName/getConstructMass/getConstructCoreSize/isConstructAbandoned/isConstructIdentified/hasMatchingTransponder/getConstructOwnerEntity`; `construct.getPointOnScreen`); `render/widgets` + `render/ar_layer` + `render/gunner_view`; `bootstrap_gunner` wiring `onUpdate/onFlush/onTick` + `weapon_*.onHit/onMissed`, `core.onStressChanged`, `shield.onAbsorbed`, `construct.onPvPTimer`; `build.ps1` gunner target → `gunner_seat_hud.conf`; in-game validation on a gunner seat.

---

_Plan saved 2026-06-26. Branch `pvphud-phase2`. Phase 2B (gunner assembly + render + DU wiring + in-game) follows once this core is green and reviewed._
