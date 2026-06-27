# Dual Universe Lua — Knowledge Index (for agents in new sessions)

Hard-won facts about scripting Dual Universe (DU) Programming Boards / Screens, learned
the slow way while building `BaseMonitor`. **Read this before touching DU Lua** — several of
these cost hours of debugging and are not obvious from the docs.

Authoritative API source: the official mockups at
`https://github.com/dual-universe/lua-examples/tree/main/api-mockup`
(`element.lua`, `container.lua`, `coreunit.lua`, `screenunit.lua`, `system.lua`, `renderScript.lua`).
Fetch the raw files to confirm signatures.

---

## 0. TL;DR of the biggest gotchas

1. **`_G` is NOT the script environment.** Injected globals (`system`, `unit`, `slot1`…`slot10`,
   `library`, `construct`, `player`) are **direct globals** and are **absent from `_G`**.
   Read them by bare name, never `_G.system` / `_G["slot"..i]` (those return `nil` in-game).
2. **`screen.setHTML()` is deprecated** and won't render reliably. Use **render scripts**:
   `screen.setRenderScript(code)` + `screen.setScriptInput(data)`; the render script reads
   `getInput()` and draws with the screen render API.
3. **`container.getContent()` only works on the `ItemContainer` class (Container Hubs).**
   Standalone S/M/L/XL containers report class `Container<Size>Group` and **never** expose their
   item list (no `getContent`, no `onContentUpdate`) — only their **volume/mass**. This is an
   engine limitation; even LocuraDU can't read standalone container contents.
4. **`system.print()` goes to the in-game Lua console only — NOT the game log file.** The XML
   logs (`%LOCALAPPDATA%\NQ\myDU\log`) capture Lua **errors** but not print output.
5. **The board import format is a `config.json`** (slots + handlers), pasted into the in-game Lua
   editor — **not** the autoconf `.conf` YAML used by `autoconf/custom/*.conf`.

---

## 1. The board `config.json` format

A Programming Board script is imported as JSON (Ctrl+V into the in-game Lua editor). Structure:

```json
{
  "slots": {
    "0": {"name": "slot1", "type": {"events": [], "methods": []}},
    "...": "...",
    "9": {"name": "slot10", "type": {...}},
    "-1": {"name": "unit",      "type": {...}},
    "-2": {"name": "construct", "type": {...}},
    "-3": {"name": "player",    "type": {...}},
    "-4": {"name": "system",    "type": {...}},
    "-5": {"name": "library",   "type": {...}}
  },
  "handlers": [
    {"code": "<lua>", "filter": {"args": [], "signature": "onStart()", "slotKey": "-1"}, "key": "0"},
    {"code": "<lua>", "filter": {"args": [{"variable":"*"}], "signature": "onTimer(timerId)", "slotKey": "-1"}, "key": "1"}
  ],
  "methods": [],
  "events": []
}
```

- A Programming Board has **10 element slots** (`slot1`…`slot10`, JSON keys `"0"`…`"9"`) plus the
  five built-in negative slots. The user links elements to slots; the slot's `name` becomes the
  global variable. We ship slots named `slot1`…`slot10`, so the globals are `slot1`…`slot10`.
- **Handler filter:**
  - `slotKey` = which element emits the event (`"-1"` = `unit` for `onStart`/`onTimer`; `"0".."9"`
    for a specific slot's element events like `onContentUpdate`).
  - `signature` = e.g. `"onStart()"`, `"onTimer(timerId)"`, `"onContentUpdate()"`.
  - `args` = one `{"variable":"*"}` per event parameter (wildcard match); `[]` for no-arg events.
    For `onTimer`, filter `[{"variable":"*"}]` and check `timerId` in code.
  - `key` = unique handler id (string or number both import; we use strings).
- Unit events: `onStart()`, `onStop()`, `onTimer(timerId)`.
- `system` (slot -4) events: `onActionStart/Loop/Stop(action)`, `onUpdate()`, `onFlush()`,
  `onInputText(text)`, `onCameraChanged(mode)`.
- Generator reference: `wolfe-labs/DU-LuaC` `src/lib/DULuaConfig.ts` defines this format.
- Autoconf `.conf` files apply to **control units** (remote controller, gunner seat, pilot/command seats) via the in-game **Autoconfigure** button — programming boards use `config.json` and cannot take a `.conf`. A `require`-shim bundle (per-module `__mods[...]` loaders inlined under a `lua: |` block, falling back to DU's real `require` for libs like `dkjson`) loads and renders correctly on a control unit — validated 2026-06-26 with the PVPHud self-test on a Remote Controller.
- **Autoconf slot globals & `select: manual` (cost hours — PVPHud bug):** a slot named `foo`
  with `select: manual` exposes the **element** as `foo_1` (and `foo_2`…) plus a bare-name
  **array** `foo` (with `foo_size`). Use **`foo_1`** to call element methods; the bare `foo`
  is a table and calling element methods on it errors `attempt to call a nil value (field
  '...')`. (GFL uses `radar_1`/`db_1`/`ammoCont_1` for its manual slots, and `weapon` as an
  array.) A slot with no `select:` gives the element directly under the bare name.
- **Repeated handler keys are valid** in autoconf: multiple `actionStart:`+`args:[optionN]`
  (or `onActionStart:`) siblings under one `system:` mapping are the normal pattern — the
  official `sample.conf` ships 12 duplicate `onActionStart:` keys. DU's importer is **not** a
  strict YAML parser; do not "dedupe" them. `option1..9` = Alt+1..9; `lua1..5` = Lua tabs.
- **`getPointOnScreen` is on `library`, NOT `construct` or `system`** (cost hours — PVPHud bug):
  `library.getPointOnScreen({x,y,z})` → `{sx, sy, depth}` (fractions 0..1 of screen; `depth<=0`
  = behind camera). Confirmed in the official `api-mockup` (absent from construct.lua/system.lua)
  and by GFL/ArchHUD. Multiply by `system.getScreenWidth()/Height()` for pixels.
- **Authoritative API method names: read `github.com/dual-universe/lua-examples/api-mockup`**
  raw files — file names are lowercase singular, e.g. `shieldgenerator.lua`, `weapon.lua`,
  `radar.lua`, `construct.lua`, `system.lua`, `element.lua`. Do NOT trust community-HUD method
  names blindly (they can be deprecated/renamed). Shield ship API: `getShieldHitpoints`,
  `getMaxShieldHitpoints`, `getResistances`, `setResistances(am,em,ki,th)`, `getResistancesPool`,
  `getResistancesCooldown`, `getStressRatioRaw`, `isVenting`, `startVenting`/`stopVenting`,
  `getVentingCooldown`.
- **A HUD `.conf` on a control unit REPLACES the unit's entire Lua, including built-in flight
  control** (cost a test session — PVPHud). A HUD on a remote controller / cockpit / seat must
  **embed flight control** or the ship won't fly: it drifts/spins (no angular-velocity damping)
  and WASD is dead. The standard minimal flight loop is the **official `sample.conf`**:
  `Nav = Navigator.new(system, core, unit)` in onStart; `onFlush` builds `targetAngularVelocity`
  from `pitchInput`/`rollInput`/`yawInput` and applies `Nav:setEngineCommand('torque', vec3(),
  angularAccel)` (driving angular velocity toward the target — **target is 0 with no input, so
  this is what stabilizes**); `onUpdate` calls `Nav:update()`; action handlers map
  `forward`/`backward`→pitch, `left`/`right`→roll, `yawleft`/`yawright`→yaw,
  `speedup`/`speeddown` (**mouse wheel**) →
  `Nav.axisCommandManager:updateThrottleCommand(axisCommandId.longitudinal, ±0.05)`.
  **`brakeInput` is a MAGIC global** the DU runtime reads to brake — set `1`/`0` (momentary), or
  toggle with `brakeInput = 1 - brakeInput`. `Navigator`/`axisCommandId`/`vec3` are DU globals
  injected on control units. (Don't apply such a HUD to a programming board — boards don't fly.)
- **CURRENT vs stale Navigator API (the shipped `sample.conf` is OUTDATED — cost a test
  session):** `Nav:setEngineCommandFromThrottle`, `Nav:composeLiftUpAcceleration`, and
  `Nav:setBoosterCommand` from the old sample are **removed** (nil at runtime). The current
  translation pattern (per ArchHUD/GFL, working today) is:
  `local a = Nav.axisCommandManager:composeAxisAccelerationFromThrottle('thrust analog
  longitudinal', axisCommandId.longitudinal); Nav:setEngineForceCommand('thrust analog
  longitudinal', a, 1)` — same for `'thrust analog vertical'` with `axisCommandId.vertical`.
  `Nav:setEngineCommand('torque', vec3(), angularAccel)` still works. **`unit.hideWidget()`**
  in onStart hides the default control widget (it otherwise fights script throttle/brake).
  When unsure of a Navigator/engine method, grep a CURRENT working HUD (`archhud/apclass.lua`,
  `GFL_Pilot_2.3.conf`) — NOT the stale `sample.conf`.
- **Braking must be COMMANDED — setting `brakeInput` alone does nothing** in custom flight
  (cost a test session — PVPHud; the HUD showed "BRAKE ON" but the retro-rockets never fired).
  Per GFL_Pilot, command the brake elements each `onFlush`:
  `local v = vec3(construct.getWorldVelocity()); local f = brakeInput * construct.getMaxBrake()
  * (-v:normalize()); if v:len() < 5 then f = brakeInput * -(30*v + v:normalize() +
  vec3(construct.getWorldGravity())) end; Nav:setEngineForceCommand('brake', f)`. The `'brake'`
  tag takes a **force** vector (N, magnitude `getMaxBrake()`), opposing velocity; zero force
  releases the brakes. This drives BOTH space retro-rockets and atmo brakes. (PVP flight
  references: `GFL_Pilot_2.3.conf`, `FOX_Flight.conf`; ArchHUD is PVE-leaning.)

**Handler size:** large handlers are accepted (we ran ~25 KB onStart fine), but if a handler ever
runs **only its first line and then silently stops**, suspect a size limit and minify/split
(LocuraDU splits across `library`/`system`/`unit` handlers; DU-LuaC minifies).

---

## 2. `_G` is not `_ENV` (the #1 time sink)

In DU's sandbox, the injected globals live in `_ENV` but `_G` is a **separate table** that does
not contain them. Symptoms when you get this wrong: the script "does nothing" yet only the first
`system.print` shows (because `dbg` guarded on `_G.system` is silently skipped), and slots scan as
empty.

```lua
-- WRONG (returns nil in-game):
if _G.system then _G.system.print(x) end
local s = _G["slot"..i]

-- RIGHT:
if system then system.print(x) end
local raw = { slot1, slot2, slot3, slot4, slot5, slot6, slot7, slot8, slot9, slot10 }
```

You cannot build a slot name dynamically (`_G["slot"..i]` fails), so enumerate `slot1..slot10`
by literal name. Reading an unlinked slot global is `nil` (no error). For config, **pass values
explicitly** (e.g. `BIM.start({...})`) rather than via `_G`.

---

## 3. Element API (common to all linked elements)

From `element.lua`. Call methods with **dot** (`el.getName()`), they're closures on the element.

- `getName()` → element's in-game custom name (the name the player typed). **No Core needed.**
- `getClass()` → class string, e.g. `"ScreenUnit"`, `"CoreUnitStatic"`, `"ItemContainer"`,
  `"ContainerMediumGroup"`, `"ContainerLargeGroup"`. Use `string.match(cls,"Screen")` /
  `"Container"` to classify. (`getElementClass()` is deprecated.)
- `getLocalId()` → element local id (use with Core's `getElement*ById`). (`getId()` deprecated.)
- `getMass()`, `getItemId()`, `getIntegrity()`, `getHitPoints()`, `getMaxHitPoints()`, …
- `isInClass(name)` / `isInClassId(id)`.

Detect elements by scanning your own slots and calling `getClass()` — link order doesn't matter,
no Core required:
```lua
-- screen: cls:find("Screen", 1, true) ; containers/hubs: cls:find("Container", 1, true)
```

---

## 4. Containers & contents (the second big time sink)

From `container.lua` (a Container is an Element):

- `getItemsVolume()` → current contents volume, **liters** (real-time, always works).
- `getMaxVolume()` → max volume, liters.
- `getItemsMass()` → contents mass, **kg** (tons = kg/1000).
- `getSelfMass()` → empty container mass, kg.
- `getContent()` → `{ {id=<int>, quantity=<float>}, ... }` per stack. **Replaces the deprecated
  `getItemsList()`.**
- `updateContent()` → request a content sync; **throttled to 1 call / 30 s** (returns remaining
  wait seconds). Emits `onContentUpdate` when the sync arrives.
- Event `onContentUpdate` → fires when content is (re)synced.

### CRITICAL: getContent only works on hubs
- **`ItemContainer` class (Container Hub) → `getContent()` returns the item list.** ✅
- **`Container<Size>Group` class (standalone S/M/L/XL) → `getContent()` always returns `{}`,
  and `onContentUpdate` never fires**, even though `getItemsVolume()` shows the container is
  physically full. ❌

This means: **you cannot read which items are in a standalone container.** Volume/mass yes,
item list no. Confirmed empirically (BUILD 11: only the `ItemContainer` slot fired
`onContentUpdate`) and by LocuraDU's code (it calls `getContent()` on the hub slot only;
otherwise the user configures the item id per container).

**Implications for "name a container by its contents":**
- Hubs → auto-label from `getContent()`.
- Standalone containers → impossible to auto-read. Options: (A) the user renames the container
  in-game and you show `getName()`; (B) the user puts each category behind its own hub; (C) the
  user configures an item id per slot (LocuraDU's approach).

`Container Hub` is `ItemContainer`; volume on a hub reflects the **combined** pool of all
containers attached to it.

---

## 5. `system` API & item taxonomy

From `system.lua`:

- `system.print(msg)` → in-game Lua console (NOT the log file).
- `system.getItem(id)` → item table:
  `{id, name, displayName, locDisplayName, displayNameWithSize, locDisplayNameWithSize,
    description, locDescription, type, unitMass, unitVolume, tier, size, iconPath, schematics, products}`.
- `system.isItemInClass(itemId, className)` / `isItemInClassId(itemId, classId)`.
- HUD: `system.setScreen(html)` renders HTML on the **player HUD** (covers the view); only works
  when running the board **explicitly (press F)**, not via plug signal. `system.showScreen(bool)`
  toggles it. `getScreenWidth/Height()`.

### `system.getItem(id).type` is COARSE — only three values
- `"object"` → elements/parts (engines, screens, ammo, fuel tanks, components, screws…)
- `"material"` → **everything craftable**: ores, pures, products, fuels, gases (all the same `type`!)
- `"worldMaterial"` → honeycomb / surface paints

So `type` alone can't tell Ore from Pure from Product (all `material`). To get friendly categories
you must sub-classify `material`:
- Ore: match against the **19-ore set** (the only reliable way — ores have no name pattern):
  Quartz, Hematite, Coal, Bauxite (T1); Limestone, Natron, Malachite, Chromite (T2);
  Garnierite, Petalite, Pyrite, Acanthite (T3); Cryolite, Cobaltite, Kolbeckite (T4);
  Columbite, Rhodonite, Ilmenite, Vanadinite (T5).
- Pure: name matches `^Pure ` (incl. tier-0 gases Pure Oxygen/Hydrogen).
- Fuel: name contains fuel/nitron/kergon/xeron. Scrap: name contains scrap.
- else → Product (refined materials, alloys, plastics, glass, components).

`tier` is `0..5` (0 = gases). Items are static → cache `system.getItem` results.

---

## 6. Screen render scripts (replaces setHTML)

`screen.setHTML(html)` is **deprecated** (logs a warning, renders unreliably). Use render scripts.

Board side (`screenunit.lua`):
- `screen.setRenderScript(codeString)` → install the render script (set once).
- `screen.setScriptInput(string)` → push data to it (each refresh). `getScriptOutput()` reads back.
- `screen.activate()` to turn the screen on.

Render-script side (`renderScript.lua`) — runs ON the screen each frame, separate sandbox with
`math`/`string`/`table` + the render API:
- `getResolution()` → `rx, ry`.  `getInput()` → the string set by `setScriptInput`.
- `createLayer()` → layer handle.  `loadFont(name, sizePx)` → font (use integer size!).
  Valid fonts include `Play`, `Play-Bold`, `RobotoMono`, `RobotoCondensed`, `FiraMono`, `Montserrat`, `Oxanium`.
- `setNextFillColor(layer, r,g,b,a)` (floats 0..1), `setNextShadow(layer, radius, r,g,b,a)` (glow),
  `setNextTextAlign(layer, alignH, alignV)`.
- `addBox(layer,x,y,w,h)`, `addBoxRounded(layer,x,y,w,h,radius)`, `addText(layer,font,text,x,y)`,
  `addLine`, etc.
- Align constants: `AlignH_Left/Center/Right`, `AlignV_Top/Middle/Bottom/Ascender/Baseline/Descender`.

Pass structured data board→screen by encoding a string in `setScriptInput` (e.g. tab/newline rows)
and parsing it with `gmatch` in the render script — avoids needing a JSON lib on the screen.

Trick for readable text over a progress bar: draw a **translucent** fill (`a≈0.5`) and **white text
with a dark `setNextShadow` outline** so it reads over both filled and empty areas.

---

## 7. Debugging in DU (no log access for prints)

- `system.print` → **in-game Lua console** (chat → Lua tab) only. The XML log
  (`%LOCALAPPDATA%\NQ\myDU\log\log_*.xml`) does **not** contain print output.
- Lua **errors** DO appear in the XML log as `<message>[Handler:<slot>] Lua runtime error: ...`.
  Grep for that to find crashes. (We can read the user's logs.)
- Lua compiles the whole chunk before running — if the **first line runs**, the chunk compiled
  fully (no truncation/syntax error). If execution stops after line 1 with no error, suspect a
  silent guard (e.g. `_G.system` nil) or a size limit.
- **Always embed a build number/timestamp** printed first thing, so the user can confirm a new
  paste actually loaded (DU pastes don't always take; an old script can keep running).
- Add targeted `system.print` diagnostics behind a `debug`/`bimDebug` export toggle.

---

## 8. This project (`BaseMonitor`) workflow

- **Single source of truth:** `BaseMonitor/baseinventory.lua` (pure logic + DU bootstrap, exposes
  global `BIM`; ends with `return M` for `dofile()` in tests).
- **Build:** `pwsh -File BaseMonitor/build.ps1` → generates `BaseMonitor.config.json`
  (strips the trailing `return M`, inlines source under `onStart`, adds `--export` locals passed
  to `BIM.start({...})`, plus `onTimer` and per-slot `onContentUpdate` handlers). Bumps a shared
  build number in `BaseMonitor/.buildno`. **Never edit the `.json` by hand.**
- **Tests:** `"/c/Users/pawel/AppData/Local/Programs/Lua/bin/lua.exe" BaseMonitor/tests/run.lua`
  (install Lua via `winget install DEVCOM.Lua`; binary is `lua`, not `lua54`). Tests stub the DU
  globals in `BaseMonitor/tests/stubs.lua`. Keep shipped code **Lua 5.3-safe** (DU runtime),
  though tests run on 5.4.
- **Simulate the real chunk:** extract `handlers[0].code` from the generated JSON and run it with
  stubbed `slot1..`, `system`, `unit` to verify the full in-game path (incl. that `_G` ≠ `_ENV`).
- Screen renders via render script; HUD mirror (`system.setScreen`) is opt-in (`bimHud`, off by
  default — it covers the whole view).
- `labelMode` export: `auto` (category → item names → element name) | `category` | `items` | `name`.

---

## 9. Quick reference: what works on what

| Need | API | Works on |
|------|-----|----------|
| Container fill % | `getItemsVolume()/getMaxVolume()` | all containers + hubs |
| Container mass | `getItemsMass()` (kg) | all containers + hubs |
| Item list (contents) | `getContent()` + `updateContent()`/`onContentUpdate` | **hubs (`ItemContainer`) only** |
| Element name | `getName()` | all elements |
| Element class | `getClass()` | all elements |
| Item details | `system.getItem(id)` | always (id from `getContent`) |
| Screen output | `setRenderScript()` + `setScriptInput()` | screens (setHTML deprecated) |
| HUD output | `system.setScreen()` (+`showScreen`) | player HUD, only when running board with F |
| Print/debug | `system.print()` | in-game Lua console (not log file) |

---

_Last updated: 2026-06-25, after BaseMonitor BUILD 11. If you discover a new DU API fact, append it
here so the next session doesn't rediscover it the hard way._
