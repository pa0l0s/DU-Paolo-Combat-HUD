# Base Inventory Monitor (Synthwave)

A Dual Universe Programming Board script that shows your base storage containers'
fill levels on a Screen, in a neon Retro-Synthwave theme.

## Install

1. Place a **Programming Board** and a **Screen** on your base.
2. Right-click the board → **Advanced → Run Lua script → paste** the contents of
   `BaseMonitor.conf` (it's a DU autoconf — paste the whole file).
3. With the **Link tool**, link the board to:
   - the **Core** unit  → slot `core`
   - the **Screen**     → slot `screen`
   - each **Container**  → slots `container1`, `container2`, … (any order)
4. Activate the board.

> Only link what you have. Empty `containerN` slots are skipped silently — no errors.
> Up to 24 containers; add more slots in `baseinventory.lua` + rerun `build.ps1` if needed.

## Naming your containers = naming your groups

The script **cannot read what items are inside a container** (DU does not expose that).
The container's **in-game name is the label shown on screen**. Name each container after the
item group it holds, e.g.:

- `T1 Ore`, `Pure T1`, `Light Metal Prod T1-2`, `Heavy Metal Prod T1-2`,
  `Conductor T1-2`, `Plastic`, `Glass`, `Simple Components T1`

If one container holds several groups, give it a joined name yourself, e.g. `Ore + Pure T1`.
The fill bar and mass are always accurate (read as true volume), even for mixed contents.

## Tuning (edit the `--export` values on the board, or in `baseinventory.lua`)

| Setting | Default | Meaning |
|---------|---------|---------|
| `refreshSeconds` | 5 | how often the screen updates |
| `warnPct` | 75 | yellow warning threshold |
| `critPct` | 90 | pink pulsing critical threshold |
| `sortMode` | `fill-desc` | `fill-desc`, `fill-asc`, `name`, or `none` |
| `title` | `BASE INVENTORY` | header text |

## Developing

- Single source of truth: `baseinventory.lua`.
- Run tests: `lua tests/run.lua` (install Lua via `winget install DEVCOM.Lua`; the DEVCOM.Lua install may name the binary `lua` or `lua54`; use whichever resolves).
- Regenerate the autoconf: `pwsh -File build.ps1` → `BaseMonitor.conf`.
