# Role & Objective
You are an expert Lua developer specializing in Dual Universe (DU) in-game scripting, UI design, and the Codex API. 
Your task is to analyze the provided example scripts, understand the Dual Universe execution environment for a Programming Board (PB), and develop a production-ready script that displays container storage levels on a Screen unit connected to a Static Construct (Base).

# Context & Source Material
Please analyze the example Lua scripts and documentation located at:
- D:\Source\DualUniverse
- https://github.com/dual-universe/lua-examples
- https://docs.google.com/spreadsheets/d/1dqmvSw6pGhrxYn8NUDHAHEtLJgGdubgz95tPdVVrris/edit?gid=531217013#gid=531217013
- https://github.com/LocuraDU
- https://github.com/Jason-Bloomer/DU-Lua-Scripts
- https://du-creators.org/?c=eyJmIjoic2h1ZmZsZSIsImkiOjE1LCJrIjpudWxsLCJvIjoiYXNjIiwiciI6MC45MTY4MywicyI6MCwidCI6W10sInkiOiJzY3JpcHQifQ

Focus on:
1. How the scripts handle the `core` or `container` APIs on a Static Construct.
2. The patterns used for event loops (`unit.tick`, `system.updateTimer`).
3. Methods for rendering UI (SVG or HTML strings sent to `screen.setHTML`).

# Requirements & Functionality
1. **Data Aggregation:** - The script must fetch storage levels from connected containers (or via the Construct Hub/Core API if applicable in the examples).
   - It should calculate the current volume/mass versus the maximum capacity for each monitored storage unit.
2. **Architecture:**
   - Write clean, modular, and optimized Dual Universe Lua code.
   - Use standard PB slot mappings (e.g., `screen`, `core`, `storage_1`, `storage_2`, etc., or a dynamic detection approach if demonstrated in the examples).
   - Ensure proper error handling to prevent script crashes if a container is missing or unlinked.

# UI/UX Specifications (The Visual Theme)
The UI must be rendered beautifully on the connected Screen unit using HTML/CSS/SVG within `screen.setHTML()`. 
- **Theme:** Retro-Synthwave / Neon Cyberpunk.
- **Color Palette:** - Deep dark background (e.g., `#0d0211` or `#120136`).
  - Hot Neon Pink (`#ff007f`) and Electric Cyan (`#00f3ff`) as primary accents.
  - Laser Yellow (`#fffb00`) or Bright Purple (`#b10dc9`) for warnings/critical capacity alerts.
- **Visual Elements:**
  - Glowing text effects using CSS `text-shadow`.
  - Neon progress bars (SVG or CSS-styled `<div>` elements) representing container fill states with a subtle glow (`box-shadow`).
  - Scanlines or a subtle retro grid effect if performance permits.
  - Clean layout displaying: Container Name, Item Count/Volume, Percentage Full, and a visual progress bar.

# Output Format
Provide the complete code structured for a Dual Universe Programming Board:
1. **Slot Mappings:** Clear instructions on how to link elements to the PB slots.
2. **unit.onStart():** The initialization and UI setup code.
3. **Timer / Game Loop Events:** Code handling data updates (e.g., refreshing every few seconds so it doesn't cause script lag/overhead).