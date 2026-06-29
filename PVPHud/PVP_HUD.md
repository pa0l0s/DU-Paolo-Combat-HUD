# Role & Context
You are an expert Lua and configuration file developer specializing in custom UI/HUD development for Dual Universe (or applicable game engine). Your task is to generate two distinct PvP HUD configuration files by analyzing, extracting, and merging features from two existing reference implementations found in the local folder: `FOX HUD` and `GFL HUD`.

# Target Outputs Required
1. `gunner_seat_hud.conf` (Optimized for active target tracking, firing, and weapon mechanics)
2. `remote_controller_hud.conf` (Optimized for piloting/remote operations, spatial awareness, and defense)

# Core Architecture & Reference Directives
- **Codebase Fusion:** Analyze the existing files in the `E:\GRY\My Dual Universe\Game\data\lua\autoconf\custom`. Identify common utilities and distinct features. Synthesize the robust structural baseline of the GFL HUD with the advanced tracking/rendering capabilities of the FOX HUD.
- **Modularity:** Ensure the generated files are clean, commented, and modular, separating UI rendering (SVG/HTML/CSS) from the underlying logic and event listeners.

# Required Feature Specifications

### 1. Advanced Shield Management
- **Manual Shield Venting:** Implement a keybind listener for `Alt+Shift+6` that triggers the shield venting sequence.
- **Dynamic Auto-Resist Allocation:** Implement an automated algorithm that reads incoming damage types (Kinetic, Thermic, Electromagnetic, Antimatter) and dynamically shifts shield resistance points to maximize mitigation against the highest damage type received.

### 2. Telemetry & Performance Analytics
- **Damage Graphs:** Render two real-time, smooth performance graphs on the UI overlay:
  - **Damage Received Graph:** Tracks incoming DPS trends.
  - **Damage Caused Graph:** Tracks outgoing DPS trends.
- **Weapon & Engagement Metrics:** 
  - **Optimal Range Indicator:** Dynamically calculate and display the optimal firing range based on the currently selected weapon/ammo profile.
  - **Radar Identification Range:** Display a visual boundary or numerical readout indicating when a locked or tracked target falls within full identification/scanning range.

### 3. Flight & Control Mechanics
- **Smooth Control Mode:** Replicate the specialized flight smoothing/damping behavior found in the `GFL HUD`. This mode must toggle on/off globally when the user presses the `Spacebar`. Ensure visual feedback (e.g., "SMOOTH MODE: ACTIVE") is rendered on the screen.

### 4. Target Tracking & Memory Persistence
- **Core Position Memory:** Port the core tracking features from the `FOX HUD`. The system must:
  - Cache and remember the 3D coordinates of targeted construct cores.
  - Persistently draw these core positions on the screen as 3D-to-2D projected augmented reality (AR) markers, even if the target is temporarily lost on radar.

### 5. Feature Discovery
- Thoroughly scan the reference files for any secondary quality-of-life features (e.g., speedometers, crosshair variations, horizon lines, fuel gauges, or custom CSS themes). Systematically incorporate these discovered features into both generated configuration files where appropriate.

# Prompt Output Requirements
Provide the complete, production-ready code blocks for both configuration files. Do not use placeholders, shorthand, or truncated code snippets. Include inline comments explaining the logic for the keybind mapping and the automated shield resistance calculation loop.