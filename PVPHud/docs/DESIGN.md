# Retrosyncwave PvP HUD System — Design

> Two cooperating Dual Universe HUDs built from one SOLID, unit-tested codebase.
> One player runs **both** stations at once: the **Remote Controller** flies the
> ship, the **Gunner Seat** fires the guns. They share state through a common
> **DatabankUnit**.

Status: **approved design** (2026-06-25). This document is the human-readable
source of truth for the architecture. Implementation follows the `BaseMonitor`
workflow described in `../../DU-LUA-KNOWLEDGE.md` §8 (pure Lua modules + a build
step that emits the shippable config + desktop unit tests with stubbed DU globals).

---

## 1. Concept & roles

The system ships **two autoconf `.conf` files**, each a HUD that runs on its own
control unit but cooperates with the other:

| HUD | File | Owns | Responsibilities |
|-----|------|------|------------------|
| **Remote Controller** | `remote_controller_hud.conf` | the ship | flight telemetry (speed, brake dist, G, mass, top speed), **shield management** (dynamic auto-resist + manual venting), warp & fuel, radar overview, target selection, smooth/"aiming" flight mode |
| **Gunner Seat** | `gunner_seat_hud.conf` | the guns | weapon status (per-weapon state/ammo), **optimal range + hit %**, target panel, **AR target markers**, **damage-caused graph**, accuracy/shots/peak-DPS |

Division of labour (confirmed with user): **gunner = shooting only; controller =
everything else** (flight + shield + defense). The two are designed *together* as
one system, not two independent scripts.

---

## 2. The databank bus (inter-HUD communication)

Both HUDs link the **same DatabankUnit**. It is the only channel between them.
`core/channel.lua` owns the key schema and all encode/decode (pure, unit-tested);
no other module touches raw databank keys.

| Key | Writer → Reader | Type | Meaning |
|-----|-----------------|------|---------|
| `pilotTarget` | either → both | int | selected target construct id |
| `friendlist` | either → both | JSON | friend construct ids (friend/enemy classification) |
| `deadCores` | radar → both | JSON | cached dead-core world positions (persistent AR memory) |
| `targetSpeed` | gunner → controller | int | last known target speed (km/h, `-1` = unknown) |
| `GunnerSystem` | either → both | int(0/1) | gunner-system overlay toggle |
| `RedSquare`/`GreenSquare`/`YellowSquare`/`BlueSquare` | either → both | int(0/1) | shared status-light toggles |

Design rules:
- **No key is read without a default.** Missing key ⇒ documented default (see
  `channel.lua`). Both HUDs seed missing keys on `onStart`.
- Writes are **idempotent** and cheap; the databank is polled, not event-driven,
  to keep the two HUDs decoupled (either can be absent and the other still runs).

---

## 3. Data flow

```
                 ┌──────────────────────────────────────────────┐
                 │                DatabankUnit (bus)             │
                 │  pilotTarget · friendlist · deadCores · ...   │
                 └───────▲───────────────────────────▲──────────┘
                         │ channel.lua                │ channel.lua
        ┌────────────────┴───────────┐    ┌───────────┴────────────────┐
        │   REMOTE CONTROLLER HUD    │    │      GUNNER SEAT HUD        │
        │                            │    │                            │
        │  du/ adapters  ───────►    │    │  du/ adapters  ───────►     │
        │   radar shield warp fuel   │    │   radar weapon ammo         │
        │           │                │    │           │                │
        │           ▼                │    │           ▼                │
        │  core/ (pure logic)        │    │  core/ (pure logic)        │
        │   resist dps threat        │    │   ballistics dps tracking  │
        │   tracking format          │    │   threat format            │
        │           │                │    │           │                │
        │           ▼                │    │           ▼                │
        │  render/ (state→SVG/HTML)  │    │  render/ (state→SVG/HTML)  │
        │   controller_view widgets  │    │   gunner_view widgets       │
        │   ar_layer  theme          │    │   ar_layer  theme           │
        │           │                │    │           │                │
        │           ▼                │    │           ▼                │
        │  system.setScreen(html)    │    │  system.setScreen(html)    │
        └────────────────────────────┘    └────────────────────────────┘
```

Each frame (`system.onUpdate`): bootstrap pulls element state via `du/` adapters,
feeds plain tables into `core/`, passes the resulting view-state into `render/`,
and calls `system.setScreen`. Shield resist/vent runs on `onFlush`; radar scan and
DPS bookkeeping run on timers — same cadence model as the GFL references.

---

## 4. Architecture & layout

```
PVPHud/
  src/
    core/                 -- pure logic, NO DU globals — fully unit-tested
      format.lua          -- distance / speed / number formatting + grouping
      theme.lua           -- retrosyncwave palette + glow/CSS helpers (data)
      channel.lua         -- databank key schema + encode/decode + defaults
      resist.lua          -- dynamic auto-resist allocation algorithm
      dps.lua             -- rolling damage in/out buffers, peak DPS, graph points
      ballistics.lua      -- optimal range, falloff, angular/tracking thresholds, hit-% color
      threat.lua          -- friend / enemy / dead / identified classification
      tracking.lua        -- AR position cache + velocity extrapolation + dead-core persistence
    render/               -- state -> SVG/HTML strings (pure, testable)
      widgets.lua         -- shared SVG primitives: neon panel, glow text, bar, marker
      ar_layer.lua        -- lay out world-projected screen coords into AR markers
      gunner_view.lua     -- compose gunner HUD
      controller_view.lua -- compose controller HUD
    du/                   -- thin adapters over DU elements (the DIP seams; untested glue)
      radar.lua  shield.lua  weapon.lua  construct.lua  databank.lua
    bootstrap_gunner.lua      -- wire slots -> du -> core/render; register handlers
    bootstrap_controller.lua
  tests/
    stubs.lua             -- stub system/construct/radar/shield/weapon/databank/vec3
    run.lua               -- test runner
    test_*.lua            -- one per core/render module
  build.ps1               -- bundle src/ (resolve require) -> the two .conf files
  docs/DESIGN.md          -- this document
  gunner_seat_hud.conf        -- GENERATED, never hand-edited
  remote_controller_hud.conf  -- GENERATED, never hand-edited
```

### SOLID mapping
- **SRP** — every `core` module has exactly one responsibility.
- **DIP** — `core/` and `render/` depend on **plain Lua tables**, never on
  `radar`/`shield`/`weapon`. The only DU-coupled code is `du/` and the bootstraps.
- **OCP / LSP** — `du/` adapters define small interfaces; tests inject stub
  implementations that satisfy the same shape, so logic is exercised without DU.
- **ISP** — HUDs **compose** small modules; there is no 2000-line mega-handler
  like the GFL references.
- **Theme as data** — `core/theme.lua` is a palette + helper table consumed by
  `render/`. Reskinning is a one-file, unit-tested change.

### Why reimplement instead of reusing GFL
The GFL `.conf` files are heavily minified (`local function M(N,O,P,Q,R)` …),
single-file, and structurally un-testable. They are used here as **behavioral
references only**: we reimplement their algorithms (resist allocation, DPS graphs,
AR markers, ballistics) as clean, named, tested modules. Known GFL quirks (e.g.
weapon reload only dispatching while in the gunner weapon-view) are **DU action-
context limitations**, not script bugs, and are documented rather than "fixed".

---

## 5. Core algorithms (reimplemented, pure, tested)

- **`resist.allocate(incomingByType, currentResist, pool, cooldown)`** → new
  resistance vector. Reads accumulated incoming damage per type (Antimatter,
  Electromagnetic, Kinetic, Thermic), and when off cooldown, shifts the
  resistance pool toward the highest-damage type to maximise mitigation. Pure
  function of its inputs; the bootstrap supplies live values from `du/shield`.
- **`dps`** — fixed-length ring buffers for damage **received** and **caused**,
  rolling-window smoothing, peak-DPS tracking, and `graphPoints()` returning
  normalized polyline coordinates the render layer draws.
- **`ballistics`** — optimal distance, max-distance falloff curve, optimal
  tracking vs. target angular speed, and a hit-% → color band mapping.
- **`tracking`** — caches each tracked construct's world position + timestamp,
  **extrapolates by last velocity when radar contact is lost**, and persists
  dead-core positions (mirrored to the databank) so AR markers survive target loss.
- **`threat`** — classifies a construct as friend / enemy / dead / identified from
  plain inputs (threat rate, transponder match, friendlist, abandoned flag).
- **`format`** — `m`/`km`/`su` distance, `km/h` speed, thousands grouping, compact
  `k`/`m` numbers. (Direct, well-named equivalents of GFL's `q`/`z`/`w`/`E`.)

---

## 6. Theme — Retrosyncwave (classic synthwave)

`core/theme.lua` exposes a palette and glow helpers. Semantic roles map to neon:

| Role | Hex | Use |
|------|-----|-----|
| base / UI text | `#05d9e8` neon cyan | primary readouts |
| threat / incoming | `#ff2a6d` hot magenta | enemies, danger, damage-in |
| ready / friendly | `#39ff14` neon green | friends, vent-ready, good states |
| caution | `#f9f002` electric yellow | warnings, reloading |
| secondary warn | `#ff6c11` neon orange | mid-severity |
| panel background | `#0d0221` @ ~0.55 | deep-indigo glass panels |
| grid / dim | `#7700ff` violet | dead cores, faint lines |

Glow is rendered with colored `text-shadow` (neon bloom) plus a thin dark outline
for legibility over the game world. The enemy-contact body pulse becomes magenta.

---

## 7. Keybinds (real DU actions)

DU has no arbitrary `Alt+Shift+6`; it exposes fixed named actions (`option1..9` =
Alt+1..9, `lua1..5`, `brake`, `gear`, …). We keep the GFL convention and **show
the live map in an in-HUD help panel**:

| Station | Key (DU action) | Function |
|---------|-----------------|----------|
| Controller | `Space` (aiming) | smooth / aiming flight mode toggle |
| Controller | `Alt+8` (option8) | manual shield vent |
| Controller | `Alt+6` (option6) | auto-resist on/off |
| Controller | `Alt+7` (option7) | AR markers on/off |
| Controller | `Alt+1` (option1) | help panel |
| Gunner | `Alt+9` (option9) | toggle gunner AR markers |
| Gunner | chat / Lua input | enter 3-digit target code, friend filters |

---

## 8. Build & test workflow

- **Build:** `pwsh -File PVPHud/build.ps1`. A mini-bundler resolves local
  `require(...)` into one Lua chunk (DU-LuaC `package.preload` style), inlines it
  into each `.conf`'s `unit.onStart`, and emits the surrounding autoconf YAML
  (slots + event handlers: `onUpdate`/`onFlush`/`onTick`, action bindings, and
  per-element `weapon_*.onHit`, `shield.onAbsorbed`, `core.onStressChanged`, …).
  Bumps a shared build number. Writes to `PVPHud/` **and** copies to
  `E:\GRY\My Dual Universe\Game\data\lua\autoconf\custom\`. The `.conf` files are
  generated artifacts — **never edited by hand.**
- **Test:** `lua PVPHud/tests/run.lua` on desktop Lua (keep shipped code Lua
  5.3-safe). `stubs.lua` fakes the DU globals. Coverage:
  - unit tests for every `core/` module (the algorithms) and `render/` output
    (string/structure assertions),
  - a **smoke test** that bundles a bootstrap and runs `onStart` + a few
    `onUpdate` frames under stubs, asserting no errors and that `setScreen`
    received well-formed HTML (mirrors `BaseMonitor`'s "simulate the real chunk").

---

## 9. Open items / honest constraints

- **In-game validation** can't be automated here; final confirmation requires
  loading both HUDs in DU. Tests + structural lint catch logic/format errors, not
  live rendering.
- **Reload-in-weapon-view** and similar action-context behaviors are DU engine
  limits; documented, not worked around.
- **Bundler scope:** `build.ps1` supports plain local `require` of `src/`
  modules only (no external libs except `dkjson`, which DU provides via
  `require("dkjson")`).

---

_Last updated: 2026-06-25._
