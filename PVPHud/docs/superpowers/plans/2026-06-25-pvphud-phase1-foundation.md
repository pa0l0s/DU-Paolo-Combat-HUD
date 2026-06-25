# PVPHud Phase 1 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the SOLID, unit-tested toolchain for the Retrosyncwave PvP HUD system — a desktop Lua test harness, a `require`-resolving build bundler that emits autoconf `.conf` files, and the three shared core modules (`format`, `theme`, `channel`) — proven end-to-end by a generated self-test `.conf`.

**Architecture:** Pure Lua modules under `src/core/` depend only on plain tables (no DU globals). A PowerShell bundler inlines them — via a `require` shim that falls back to DU's real `require` for engine libs like `dkjson` — into one Lua chunk embedded in an autoconf YAML `.conf`. Tests run on desktop Lua with stubbed DU globals.

**Tech Stack:** Lua 5.3-safe (DU runtime; desktop Lua at `C:\Users\pawel\AppData\Local\Programs\Lua\bin\lua.exe`), PowerShell 7 (`build.ps1`), DU autoconf YAML `.conf` format.

## Global Constraints

- Shipped Lua must be **Lua 5.3-safe** (DU runtime); desktop tests may run on 5.4.
- `core/` and `render/` modules **must not** reference DU globals (`system`, `construct`, `radar`, `shield`, `weapon`, `unit`, `library`) — only plain tables passed in. DU coupling lives only in `du/` adapters and bootstraps.
- Generated `.conf` files are **artifacts — never hand-edited**. All changes go through `src/` + `build.ps1`.
- Module require names mirror paths: `src/core/format.lua` → `require("core.format")`.
- Retrosyncwave palette is fixed: base `#05d9e8`, threat `#ff2a6d`, ready `#39ff14`, caution `#f9f002`, warn `#ff6c11`, panel `#0d0221`, dim `#7700ff`.
- This repo is **not a git repo**. Each task ends with a **checkpoint = run the full test suite** (green). `git init` + commits are optional; if used, commit at each checkpoint.
- Run tests with: `& "C:\Users\pawel\AppData\Local\Programs\Lua\bin\lua.exe" PVPHud/tests/run.lua`

---

## File Structure (Phase 1)

```
PVPHud/
  src/
    core/
      format.lua    -- distance / speed / number formatting
      theme.lua     -- retrosyncwave palette + CSS/glow helpers
      channel.lua   -- databank key schema + typed get/set + defaults
    bootstrap_smoke.lua -- tiny entry proving the bundle pipeline
  tests/
    stubs.lua       -- DU global stubs (vec3, databank, system)
    run.lua         -- manifest-driven test runner
    test_format.lua
    test_theme.lua
    test_channel.lua
    test_bundle_smoke.lua
  build.ps1         -- bundler: src/ -> pvphud_selftest.conf (+ copy to custom)
  .buildno          -- shared build counter (generated)
  pvphud_selftest.conf -- GENERATED self-test artifact
```

---

### Task 1: Test harness (runner + stubs) and `format` module

**Files:**
- Create: `PVPHud/tests/run.lua`
- Create: `PVPHud/tests/stubs.lua`
- Create: `PVPHud/src/core/format.lua`
- Test: `PVPHud/tests/test_format.lua`

**Interfaces:**
- Produces: global `T` with `T.eq(actual, expected, msg)` and `T.ok(cond, msg)`; runner reads `tests/manifest.lua` (a `return {<names>}` list) and `require`s each. `core.format` exposes `groupThousands(n)`, `distance(m)`, `speed(mps)`, `compact(n)` — all returning strings.
- Consumes: nothing (first task).

- [ ] **Step 1: Write the failing test**

Create `PVPHud/tests/test_format.lua`:

```lua
local fmt = require("core.format")
T.eq(fmt.groupThousands(1234567), "1,234,567", "groupThousands millions")
T.eq(fmt.groupThousands(42), "42", "groupThousands small")
T.eq(fmt.groupThousands(-12345), "-12,345", "groupThousands negative")
T.eq(fmt.distance(500), "500m", "distance metres")
T.eq(fmt.distance(2500), "2.5km", "distance km")
T.eq(fmt.distance(400000), "2.00su", "distance su")
T.eq(fmt.speed(nil), "", "speed nil")
T.eq(fmt.speed(100), "360 km/h", "speed mps->kmh")
T.eq(fmt.compact(1500), "1.5k", "compact thousands")
T.eq(fmt.compact(2300000), "2.3m", "compact millions")
```

Create the runner `PVPHud/tests/run.lua`:

```lua
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
```

Create `PVPHud/tests/manifest.lua`:

```lua
return {
  "test_format",
}
```

Create `PVPHud/tests/stubs.lua` (used by later tasks; created now so the harness is complete):

```lua
-- Stub DU globals for desktop testing. No DU runtime needed.
local M = {}

local vmt = {}; vmt.__index = vmt
local function vec3(x, y, z)
  if type(x) == "table" then x, y, z = x[1] or x.x, x[2] or x.y, x[3] or x.z end
  return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, vmt)
end
function vmt.__sub(a, b) return vec3(a.x - b.x, a.y - b.y, a.z - b.z) end
function vmt.__add(a, b) return vec3(a.x + b.x, a.y + b.y, a.z + b.z) end
function vmt:len() return math.sqrt(self.x^2 + self.y^2 + self.z^2) end
function vmt:normalize()
  local l = self:len(); if l == 0 then return vec3(0, 0, 0) end
  return vec3(self.x / l, self.y / l, self.z / l)
end
M.vec3 = vec3

function M.newDatabank(initial)
  local store = {}
  for k, v in pairs(initial or {}) do store[k] = v end
  return {
    hasKey = function(k) return store[k] ~= nil end,
    getIntValue = function(k) return tonumber(store[k]) or 0 end,
    setIntValue = function(k, v) store[k] = v end,
    getStringValue = function(k) return tostring(store[k] or "") end,
    setStringValue = function(k, v) store[k] = v end,
    _store = store,
  }
end

function M.newSystem()
  local last = { screen = nil, prints = {} }
  return {
    setScreen = function(html) last.screen = html end,
    showScreen = function() end,
    print = function(m) table.insert(last.prints, m) end,
    getScreenWidth = function() return 1920 end,
    getScreenHeight = function() return 1080 end,
    getUtcTime = function() return 0 end,
    _last = last,
  }
end

return M
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\pawel\AppData\Local\Programs\Lua\bin\lua.exe" PVPHud/tests/run.lua`
Expected: FAIL — `test_format errored: module 'core.format' not found` (and non-zero exit).

- [ ] **Step 3: Write minimal implementation**

Create `PVPHud/src/core/format.lua`:

```lua
-- Pure number/distance/speed formatting. No DU globals.
local M = {}

-- 1234567 -> "1,234,567" (handles negatives).
function M.groupThousands(n)
  local s = tostring(math.floor(n))
  local sign = ""
  if s:sub(1, 1) == "-" then sign = "-"; s = s:sub(2) end
  while true do
    local r
    s, r = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
    if r == 0 then break end
  end
  return sign .. s
end

-- metres -> m / km / su (1 su = 200 km).
function M.distance(m)
  if m < 1000 then
    return math.ceil(m) .. "m"
  elseif m < 100000 then
    return string.format("%.1fkm", m / 1000)
  else
    return string.format("%.2fsu", m / 200000)
  end
end

-- m/s -> "12,345 km/h". nil -> "".
function M.speed(mps)
  if mps == nil then return "" end
  return M.groupThousands(math.floor(mps * 3.6)) .. " km/h"
end

-- 1500 -> "1.5k", 2300000 -> "2.3m".
function M.compact(n)
  if n < 1000 then
    return tostring(math.floor(n))
  elseif n < 1000000 then
    return string.format("%.1fk", n / 1000)
  else
    return string.format("%.1fm", n / 1000000)
  end
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\pawel\AppData\Local\Programs\Lua\bin\lua.exe" PVPHud/tests/run.lua`
Expected: PASS — `10 passed, 0 failed`, exit 0.

- [ ] **Step 5: Checkpoint**

Run the suite (Step 4) and confirm green. (Optional: `git add` + commit `feat(pvphud): test harness + format module`.)

---

### Task 2: `theme` module (retrosyncwave palette)

**Files:**
- Create: `PVPHud/src/core/theme.lua`
- Modify: `PVPHud/tests/manifest.lua` (add `"test_theme"`)
- Test: `PVPHud/tests/test_theme.lua`

**Interfaces:**
- Consumes: test harness `T` from Task 1.
- Produces: `core.theme` exposing `palette` (table of hex strings), `color(role)→hex` (fallback `base`), `glow(hex, radius?)→string`, `css()→"<style>…</style>"`.

- [ ] **Step 1: Write the failing test**

Create `PVPHud/tests/test_theme.lua`:

```lua
local theme = require("core.theme")
T.eq(theme.color("threat"), "#ff2a6d", "color threat")
T.eq(theme.color("ready"), "#39ff14", "color ready")
T.eq(theme.color("nonsense"), "#05d9e8", "color unknown -> base")
T.ok(theme.glow("#ff2a6d"):find("#ff2a6d", 1, true) ~= nil, "glow embeds hex")
local css = theme.css()
T.ok(css:sub(1, 7) == "<style>", "css starts with style tag")
T.ok(css:find(".threat{color:#ff2a6d", 1, true) ~= nil, "css has threat rule")
```

Add to `PVPHud/tests/manifest.lua`:

```lua
return {
  "test_format",
  "test_theme",
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\pawel\AppData\Local\Programs\Lua\bin\lua.exe" PVPHud/tests/run.lua`
Expected: FAIL — `test_theme errored: module 'core.theme' not found`.

- [ ] **Step 3: Write minimal implementation**

Create `PVPHud/src/core/theme.lua`:

```lua
-- Retrosyncwave (classic synthwave) theme: palette + CSS/glow helpers.
-- Pure data + string builders; no DU globals.
local M = {}

M.palette = {
  base    = "#05d9e8", -- neon cyan: primary readouts
  threat  = "#ff2a6d", -- hot magenta: enemies / damage-in
  ready   = "#39ff14", -- neon green: friendly / good
  caution = "#f9f002", -- electric yellow: warnings
  warn    = "#ff6c11", -- neon orange: mid severity
  panel   = "#0d0221", -- deep indigo: panel background
  dim     = "#7700ff", -- violet: dead cores / faint grid
}

-- Semantic role -> hex; unknown role falls back to base.
function M.color(role)
  return M.palette[role] or M.palette.base
end

-- Neon glow as a CSS/SVG text-shadow string for a hex.
function M.glow(hex, radius)
  radius = radius or 6
  return string.format("0 0 %dpx %s, 0 0 %dpx %s", radius, hex, radius * 2, hex)
end

-- Shared <style> block consumed by render/.
function M.css()
  local p = M.palette
  local function rule(cls, hex)
    return string.format(".%s{color:%s;text-shadow:%s;}", cls, hex, M.glow(hex))
  end
  return "<style>"
    .. ".ui{font-family:monospace;font-weight:bold;white-space:pre;}"
    .. rule("base", p.base)
    .. rule("threat", p.threat)
    .. rule("ready", p.ready)
    .. rule("caution", p.caution)
    .. rule("warn", p.warn)
    .. "</style>"
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\pawel\AppData\Local\Programs\Lua\bin\lua.exe" PVPHud/tests/run.lua`
Expected: PASS — `16 passed, 0 failed`.

- [ ] **Step 5: Checkpoint**

Run suite, confirm green. (Optional commit: `feat(pvphud): retrosyncwave theme module`.)

---

### Task 3: `channel` module (databank bus schema)

**Files:**
- Create: `PVPHud/src/core/channel.lua`
- Modify: `PVPHud/tests/manifest.lua` (add `"test_channel"`)
- Test: `PVPHud/tests/test_channel.lua`

**Interfaces:**
- Consumes: `stubs.newDatabank` from Task 1; harness `T`.
- Produces: `core.channel` with `schema` table and `new(db, codec)→channel`. `channel` has `seed()`, `getInt(key)→int`, `setInt(key, v)`, `getJson(key)→table`, `setJson(key, table)`. `codec = {encode=fn, decode=fn}` or nil. `db` implements `hasKey/getIntValue/setIntValue/getStringValue/setStringValue`.

- [ ] **Step 1: Write the failing test**

Create `PVPHud/tests/test_channel.lua`:

```lua
local stubs = require("stubs")
local channel = require("core.channel")

local codec = {
  encode = function(t) return next(t) and "json:ne" or "json:empty" end,
  decode = function(s) return s == "json:ne" and { 1 } or {} end,
}

local db = stubs.newDatabank()
local ch = channel.new(db, codec)

-- defaults apply before seeding
T.eq(ch.getInt("pilotTarget"), 0, "default pilotTarget")
T.eq(ch.getInt("targetSpeed"), -1, "default targetSpeed")

ch.seed()
T.ok(db.hasKey("RedSquare"), "seed creates int key")
T.eq(db.getIntValue("RedSquare"), 1, "seed default value")

ch.setInt("pilotTarget", 123)
T.eq(ch.getInt("pilotTarget"), 123, "int set/get roundtrip")

ch.setJson("friendlist", { 1 })
T.eq(#ch.getJson("friendlist"), 1, "json roundtrip via codec")

-- nil db is tolerated (HUD runs without a databank)
local ch2 = channel.new(nil, nil)
T.eq(ch2.getInt("GunnerSystem"), 0, "nil db returns default")
```

Add `"test_channel"` to `PVPHud/tests/manifest.lua`:

```lua
return {
  "test_format",
  "test_theme",
  "test_channel",
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\pawel\AppData\Local\Programs\Lua\bin\lua.exe" PVPHud/tests/run.lua`
Expected: FAIL — `test_channel errored: module 'core.channel' not found`.

- [ ] **Step 3: Write minimal implementation**

Create `PVPHud/src/core/channel.lua`:

```lua
-- Databank "bus" shared by the gunner and controller HUDs.
-- Pure: operates on an injected databank object + optional JSON codec.
local M = {}

-- key -> { kind = "int"|"json", default = value }
M.schema = {
  pilotTarget  = { kind = "int",  default = 0 },
  targetSpeed  = { kind = "int",  default = -1 },
  GunnerSystem = { kind = "int",  default = 0 },
  RedSquare    = { kind = "int",  default = 1 },
  GreenSquare  = { kind = "int",  default = 0 },
  YellowSquare = { kind = "int",  default = 1 },
  BlueSquare   = { kind = "int",  default = 1 },
  friendlist   = { kind = "json", default = {} },
  deadCores    = { kind = "json", default = {} },
}

-- Build a channel over a databank object. codec = {encode=,decode=} or nil.
function M.new(db, codec)
  local self = {}

  function self.seed()
    if not db then return end
    for key, spec in pairs(M.schema) do
      if not db.hasKey(key) then
        if spec.kind == "int" then
          db.setIntValue(key, spec.default)
        elseif codec then
          db.setStringValue(key, codec.encode(spec.default))
        end
      end
    end
  end

  function self.getInt(key)
    local spec = M.schema[key]
    if not db or not db.hasKey(key) then return spec.default end
    return db.getIntValue(key)
  end

  function self.setInt(key, value)
    if db then db.setIntValue(key, value) end
  end

  function self.getJson(key)
    local spec = M.schema[key]
    if not db or not codec or not db.hasKey(key) then return spec.default end
    return codec.decode(db.getStringValue(key)) or spec.default
  end

  function self.setJson(key, value)
    if db and codec then db.setStringValue(key, codec.encode(value)) end
  end

  return self
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\pawel\AppData\Local\Programs\Lua\bin\lua.exe" PVPHud/tests/run.lua`
Expected: PASS — `23 passed, 0 failed`.

- [ ] **Step 5: Checkpoint**

Run suite, confirm green. (Optional commit: `feat(pvphud): databank channel schema`.)

---

### Task 4: Build bundler + self-test `.conf` + bundle smoke test

**Files:**
- Create: `PVPHud/src/bootstrap_smoke.lua`
- Create: `PVPHud/build.ps1`
- Modify: `PVPHud/tests/manifest.lua` (add `"test_bundle_smoke"`)
- Test: `PVPHud/tests/test_bundle_smoke.lua`
- Generated: `PVPHud/pvphud_selftest.conf`, `PVPHud/.buildno`

**Interfaces:**
- Consumes: `core.format`, `core.theme`, `core.channel` (Tasks 1–3); `stubs` (Task 1).
- Produces: `bootstrap_smoke` exposing `start(env)` where `env = { system=<sys>, build=<int>, db=<databank|nil>, codec=<codec|nil> }`; it seeds the channel, builds a banner HTML using theme+format, calls `env.system.setScreen(html)`, and returns the html string. `build.ps1` emits `pvphud_selftest.conf` and copies it to the custom autoconf folder.

- [ ] **Step 1: Write the failing test**

Create `PVPHud/tests/test_bundle_smoke.lua`:

```lua
local stubs = require("stubs")
local boot = require("bootstrap_smoke")

local sys = stubs.newSystem()
local db = stubs.newDatabank()
local codec = {
  encode = function(t) return next(t) and "json:ne" or "json:empty" end,
  decode = function(s) return s == "json:ne" and { 1 } or {} end,
}

local html = boot.start({ system = sys, build = 7, db = db, codec = codec })

T.ok(type(html) == "string", "start returns html string")
T.ok(html == sys._last.screen, "setScreen received the html")
T.ok(html:find("BUILD 7", 1, true) ~= nil, "banner shows build number")
T.ok(html:find("<style>", 1, true) ~= nil, "banner includes theme css")
T.ok(db.hasKey("pilotTarget"), "start seeds the channel")
```

Add `"test_bundle_smoke"` to `PVPHud/tests/manifest.lua`:

```lua
return {
  "test_format",
  "test_theme",
  "test_channel",
  "test_bundle_smoke",
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\pawel\AppData\Local\Programs\Lua\bin\lua.exe" PVPHud/tests/run.lua`
Expected: FAIL — `test_bundle_smoke errored: module 'bootstrap_smoke' not found`.

- [ ] **Step 3: Write minimal implementation**

Create `PVPHud/src/bootstrap_smoke.lua`:

```lua
-- Tiny entry that proves the bundle pipeline: core modules -> HUD screen.
local format  = require("core.format")
local theme   = require("core.theme")
local channel = require("core.channel")

local M = {}

-- env = { system, build, db (optional), codec (optional) }
function M.start(env)
  local ch = channel.new(env.db, env.codec)
  ch.seed()

  local html = theme.css()
    .. '<div class="ui base">'
    .. "PVPHUD SELF-TEST — BUILD " .. tostring(env.build) .. "\n"
    .. "range " .. format.distance(2500) .. "  speed " .. format.speed(100) .. "\n"
    .. "target " .. tostring(ch.getInt("pilotTarget"))
    .. "</div>"

  env.system.setScreen(html)
  return html
end

return M
```

Create `PVPHud/build.ps1`:

```powershell
# Bundles src/ Lua modules into autoconf .conf files.
# Generated .conf files are artifacts -- never hand-edit them.
param(
  [string]$Custom = "E:\GRY\My Dual Universe\Game\data\lua\autoconf\custom"
)
$ErrorActionPreference = "Stop"
$root   = $PSScriptRoot
$srcDir = Join-Path $root "src"

# Bump shared build number.
$buildFile = Join-Path $root ".buildno"
$build = 1
if (Test-Path $buildFile) { $build = [int](Get-Content $buildFile) + 1 }
Set-Content -Path $buildFile -Value $build

# Wrap modules in a require-shim that falls back to DU's real require (dkjson etc.).
function Build-Bundle([string[]]$modules, [string]$entry, [string]$bootLua) {
  $sb = [System.Text.StringBuilder]::new()
  [void]$sb.AppendLine("-- PVPHud bundle (build $build) -- GENERATED, do not edit")
  [void]$sb.AppendLine("local __realRequire = require")
  [void]$sb.AppendLine("local __mods, __cache = {}, {}")
  [void]$sb.AppendLine("local function require(name)")
  [void]$sb.AppendLine("  if __cache[name] ~= nil then return __cache[name] end")
  [void]$sb.AppendLine("  local loader = __mods[name]")
  [void]$sb.AppendLine("  if loader then local m = loader(); __cache[name] = m; return m end")
  [void]$sb.AppendLine("  return __realRequire(name)")
  [void]$sb.AppendLine("end")
  foreach ($m in $modules) {
    $file = Join-Path $srcDir (($m -replace '\.', '/') + ".lua")
    $code = (Get-Content $file -Raw).TrimEnd()
    [void]$sb.AppendLine("__mods['$m'] = function(...)")
    [void]$sb.AppendLine($code)
    [void]$sb.AppendLine("end")
  }
  [void]$sb.AppendLine("local __entry = require('$entry')")
  [void]$sb.AppendLine($bootLua)
  return $sb.ToString()
}

# Indent a block for embedding under a YAML 'lua: |' literal scalar.
function Indent([string]$text, [int]$spaces) {
  $pad = " " * $spaces
  return (($text -split "`r?`n") | ForEach-Object { if ($_ -eq "") { "" } else { $pad + $_ } }) -join "`n"
}

function Write-Conf([string]$name, [string]$confText) {
  $out = Join-Path $root $name
  Set-Content -Path $out -Value $confText -Encoding UTF8
  if (Test-Path $Custom) { Copy-Item $out (Join-Path $Custom $name) -Force }
  Write-Host "Wrote $name (build $build)"
}

# --- Phase 1 target: self-test ---
$modules = @('core.format', 'core.theme', 'core.channel', 'bootstrap_smoke')
$bootLua = "system.showScreen(1)`nfunction __pvphud_render() __entry.start({ system = system, build = $build, db = db_1, codec = (db_1 ~= nil) and require('dkjson') or nil }) end"
$bundle  = Build-Bundle $modules 'bootstrap_smoke' $bootLua

$conf = @"
name: PVPHud Self-Test
slots:
    core:
        class: CoreUnit
    db:
        class: DataBank
        select: manual
handlers:
    unit:
        onStart:
            lua: |
$(Indent $bundle 16)
    system:
        onUpdate:
            lua: |
                __pvphud_render()
"@

Write-Conf "pvphud_selftest.conf" $conf
```

- [ ] **Step 4: Run the bundler, then the suite**

Run the build first, then tests:

```
pwsh -File PVPHud/build.ps1
& "C:\Users\pawel\AppData\Local\Programs\Lua\bin\lua.exe" PVPHud/tests/run.lua
```

Expected: build prints `Wrote pvphud_selftest.conf (build 1)`; tests print `28 passed, 0 failed`, exit 0.

- [ ] **Step 5: Verify the generated artifact**

Run: `pwsh -NoProfile -Command "Select-String -Path PVPHud/pvphud_selftest.conf -Pattern \"__mods\['core.format'\]\", 'name: PVPHud Self-Test' | Measure-Object | Select-Object -ExpandProperty Count"`
Expected: `2` (both markers present — the bundle inlined `core.format` and the YAML header exists).

- [ ] **Step 6: Checkpoint**

Confirm Steps 4–5 green. (Optional commit: `feat(pvphud): build bundler + self-test conf`.)

---

## Self-Review

**1. Spec coverage (against `docs/DESIGN.md`):**
- §4 architecture (`src/core`, `tests`, `build.ps1`, generated `.conf`) — Tasks 1–4. ✅
- §2 databank bus schema + defaults — Task 3 (`channel.schema`, `seed`). ✅
- §6 retrosyncwave palette — Task 2 (`theme.palette`/`css`). ✅
- §8 build & test workflow (bundler with `require` shim → `.conf` + copy to custom; desktop tests with stubs; smoke test running the bundled entry) — Tasks 1 & 4. ✅
- §5 algorithms (`resist`, `dps`, `ballistics`, `tracking`, `threat`), §3 render layer, du/ adapters, the two real HUDs — **deferred to Phase 2 (gunner) and Phase 3 (controller) plans.** Phase 1 deliberately scopes to the foundation; this is called out in the plan intro. Not a gap — a phase boundary.

**2. Placeholder scan:** No TBD/TODO; every code step contains complete, runnable code. ✅

**3. Type consistency:** `T.eq/T.ok` used consistently; `channel.new(db, codec)` signature matches across Task 3 + Task 4 (`bootstrap_smoke`); `env` fields (`system/build/db/codec`) match between `bootstrap_smoke.start`, its test, and `build.ps1`'s `bootLua`; module require names (`core.format/core.theme/core.channel/bootstrap_smoke`) match the manifest and bundler `$modules`. ✅

**Known risk (documented, not a plan defect):** the autoconf `lua: |` literal block contains blank lines from module source. GFL reference confs include blank lines in their `lua:` blocks and load fine, so this is expected to work; if DU rejects it, the mitigation is to strip blank lines in `Build-Bundle` (safe for Lua, but must preserve any multiline string literals — none exist in Phase 1 modules). In-game load is the only true validation (per DESIGN §9).

---

_Plan saved 2026-06-25. Phases 2 (gunner) and 3 (controller) to be planned after Phase 1 validates the toolchain._
