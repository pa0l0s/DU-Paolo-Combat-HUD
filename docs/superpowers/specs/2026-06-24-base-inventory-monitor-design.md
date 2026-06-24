# Base Inventory Monitor — Design Spec

**Date:** 2026-06-24
**Target:** Dual Universe — single Programming Board (PB) on a Static Construct (base), rendering to a linked Screen via `screen.setHTML()`.
**Goal:** Display fill levels of base storage containers on a Screen, in a Retro-Synthwave / Neon Cyberpunk theme.

---

## 1. Background & API constraints (why the design is shaped this way)

These constraints were verified against the three best-known community container monitors
(Jericho1060/du-storage-monitoring, carmopereira/DU-Container-Monitor, thespartacus29/Dual-Universe-Container-Monitor):

1. **Container contents are not readable.** No reliable Lua API returns the *item types/quantities*
   inside a container. `getItemsList()` exists but is unreliable and is avoided by every production
   monitor. Therefore the script **cannot** auto-detect what a container holds, cannot derive an item
   "group", and cannot auto-rename a container from its contents.
2. **The container's name is the only contents label available.** Production monitors read the
   element name via the Core unit and treat it as the label. This fits the user's layout where each
   container already holds one item *group* (e.g. "T1 Ore", "Pure T1", "Light Metal Prod T1-2").
   The user names the container with its group; if a container holds several groups, the user writes
   a joined name. The script displays whatever the name says.
3. **Exact volume requires a linked element handle.** The Core API exposes element id/name/type/mass/HP
   but **not** per-container current/max *volume*. To get a true volume fill % (which works for
   mixed-content group containers), each container must be linked to the PB as a slot, so the script
   can call `getItemsVolume()` / `getMaxVolume()` on the handle. There is no "unlimited auto" handle
   enumeration for volume; a fixed, generous set of named slots is the standard approach.
4. **Per-item counts are impossible for group containers.** A multi-item group has differing unit
   masses, so quantity-per-item cannot be computed. Rows therefore show aggregate volume % + mass,
   not item breakdowns.

## 2. Decisions (locked with user)

- **Discovery:** fixed named container slots `container1` … `container24`, `class: ItemContainer`,
  `select: manual`. User links each group container to a slot; **unlinked/empty slots are skipped
  silently** (never error — improves on thespartacus29's error-on-disabled behavior). 24 is generous
  and trivially extendable by adding more slot entries.
- **Metric:** exact **volume fill %** from `getItemsVolume()/getMaxVolume()`, plus contents **mass**
  (tons) from `getItemsMass()`. Works for mixed-content containers.
- **Row content:** group name (the in-game element name) · neon fill bar · current/max volume
  (auto-scaled L/kL/ML/GL) · mass (t) · right-aligned %.
- **No per-item breakdown** (impossible — see §1.4).
- **Refresh:** `unit.setTimer` every `refreshSeconds` (default **5 s**), tunable via `--export`.
- **Theme:** Retro-Synthwave, rendered with HTML/CSS inside `screen.setHTML()`.

## 3. Architecture

**Single Programming Board.** Slots:

| Slot | Class | Select | Purpose |
|------|-------|--------|---------|
| `core` | CoreUnit | auto | read element name via `getElementNameById` |
| `screen` | ScreenUnit | auto | output via `setHTML` |
| `container1`..`container24` | ItemContainer | manual | volume/mass per container handle |

### Modules (logical sections within one file)

- **config** — `--export` tunables: `refreshSeconds`, `warnPct`, `critPct`, `sortMode`, `title`.
- **collect** — iterate the 24 container slot handles; for each non-nil handle, `pcall` a read of
  `getItemsVolume`, `getMaxVolume`, `getItemsMass`, and resolve label via
  `core.getElementNameById(handle.getLocalId())` (fallback `"Container N"`). Returns a list of row
  records `{label, vol, maxVol, mass, pct, ok}`.
- **format** — number formatting: volume auto-scale (L→kL→ML→GL), mass in t, percentage.
- **render** — build the HTML document string (static CSS + dynamic rows) and call
  `screen.setHTML(html)`.
- **lifecycle** — `onStart` (validate core/screen, gather slots, first render, start timer);
  `onTimer("refresh")` (re-collect + re-render).

### Data flow (per refresh)

```
onTimer("refresh")
  -> collect()  : for each linked container handle -> pcall read vol/maxVol/mass + label
  -> sort rows  : fullest-first (pct desc) by default (sortMode)
  -> aggregate  : base total vol/maxVol -> base fill %
  -> render()   : compose HTML (header + base bar + rows) -> screen.setHTML
```

## 4. Error handling

- Missing `core` or `screen` at `onStart` → render a neon error card (if screen exists) and
  `system.print` a diagnostic; do not crash.
- Each container read wrapped in `pcall`; a failed read becomes a dimmed **"OFFLINE"** row
  (`ok=false`) rather than aborting the loop.
- Zero linked containers → friendly **"No containers linked"** panel.
- `maxVol <= 0` guarded to avoid divide-by-zero (pct = 0, row flagged).

## 5. UI / UX (Retro-Synthwave)

- **Background:** `#0d0211`; subtle CSS grid + scanline overlay (low opacity, perf-light).
- **Palette:** hot pink `#ff007f`, electric cyan `#00f3ff`, laser yellow `#fffb00`,
  bright purple `#b10dc9`.
- **Header:** glowing title (`title` export), aggregate **Base total** bar, container count, refresh
  timestamp. Cyan/pink `text-shadow` glow.
- **Rows:** group name (cyan glow) · fill bar (cyan→pink gradient, `box-shadow` glow) ·
  `cur/max` volume · mass (t) · right-aligned %.
- **Thresholds:** `>= warnPct` (default 75) → laser-yellow bar; `>= critPct` (default 90) →
  hot-pink bar with pulsing glow (CSS animation).
- Rendered as one HTML string via `screen.setHTML()` (legacy HTML mode, as requested).

## 6. Deliverables (in `BaseMonitor/`)

1. **`BaseMonitor.conf`** — paste-ready DU autoconf: `slots:` + `handlers:` (`unit.onStart`,
   `unit.onTimer`). Primary artifact users paste into the PB.
2. **`baseinventory.lua`** — readable, commented single-file source with the same logic, for
   reading/editing outside the game.
3. **Slot-linking + naming instructions** — README section: link core, screen, and each group
   container to `container1..N`; name each container with its group label; joined names for
   multi-group containers.

## 7. Out of scope (YAGNI)

- Per-item / per-ingredient breakdown (impossible — §1.4).
- Auto-renaming containers from contents (impossible — §1.1).
- Multi-screen / relay fan-out, databank persistence, talent-based volume math
  (we read true volume directly, so talent math is unnecessary).
- Render-script (RS) mode — task explicitly specifies `setHTML`.

## 8. Tunables (`--export`)

| Name | Default | Meaning |
|------|---------|---------|
| `refreshSeconds` | 5 | timer interval |
| `warnPct` | 75 | warning threshold (laser yellow) |
| `critPct` | 90 | critical threshold (hot pink, pulsing) |
| `sortMode` | `"fill-desc"` | row order: `fill-desc`, `fill-asc`, `name`, `none` |
| `title` | `"BASE INVENTORY"` | header title text |
