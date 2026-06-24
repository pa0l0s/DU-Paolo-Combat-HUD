# Base Inventory Monitor (Synthwave)

A Dual Universe **Programming Board** script that shows your base storage containers'
fill levels on a **Screen**, in a neon Retro-Synthwave theme.

## Install

1. Place a **Programming Board** and a **Screen** on your base.
2. Right-click the board → **Advanced → Edit Lua script**. In the Lua editor, **paste the
   whole `BaseMonitor.config.json`** (the board accepts this JSON via paste / Ctrl+V — it is
   the same format the editor copies with Ctrl+C). Apply.
3. With the **Link tool**, link the board to:
   - the **Screen** → any free slot
   - each **Container** (or **Container Hub**) → any free slots, in **any order**
4. Activate the board.

The script **auto-detects** which linked element is the Screen and which are Containers/Hubs
by their type — you do **not** need to link things to specific slots. No Core link needed.

> A Programming Board has **10 link slots**. One goes to the Screen, leaving up to **9**
> containers/hubs. Empty slots are skipped silently — no errors.

### Tip: use one Container Hub per group

Since you organise storage by group, link **one Container Hub per group** (each hub combines
all its containers into one reported volume). Then 9 slots = 9 groups, and each row is a whole
group. You can also link individual containers directly if you prefer.

## Naming your containers = naming your groups

The script labels each row with the container/hub's **in-game name** (read via `getName()`).
**Name each container/hub after the group it holds**, e.g.:

- `T1 Ore`, `Pure T1`, `Light Metal Prod T1-2`, `Heavy Metal Prod T1-2`,
  `Conductor T1-2`, `Plastic`, `Glass`, `Simple Components T1`

If one container holds several groups, give it a joined name yourself, e.g. `Ore + Pure T1`.
The fill bar and mass are always accurate (true volume), even for mixed contents. An unnamed
container falls back to `Container N`.

## Tuning (edit the `--export` values in the board's editor, or in `baseinventory.lua`)

| Setting | Default | Meaning |
|---------|---------|---------|
| `refreshSeconds` | 5 | how often the screen updates |
| `warnPct` | 75 | yellow warning threshold |
| `critPct` | 90 | pink pulsing critical threshold |
| `sortMode` | `fill-desc` | `fill-desc`, `fill-asc`, `name`, or `none` |
| `title` | `BASE INVENTORY` | header text |

## Developing

- **Single source of truth:** `baseinventory.lua` (pure logic + DU bootstrap, exposes global `BIM`).
- **Run tests:** `lua tests/run.lua` (install Lua via `winget install DEVCOM.Lua`; the install
  may name the binary `lua` or `lua54` — use whichever resolves).
- **Regenerate the board file:** `pwsh -File build.ps1` → writes `BaseMonitor.config.json`.
  Never edit the `.json` by hand.
