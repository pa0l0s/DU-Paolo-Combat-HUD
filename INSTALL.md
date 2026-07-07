# Installation Guide — DU Paolo Combat HUD

This walks you through installing both HUDs from scratch, wiring your ship, and confirming they loaded. Time needed: a few minutes.

---

## 1. Download

Grab the release zip and unzip it anywhere:

➡ [**DU-Paolo-Combat-HUD-v28.zip**](https://github.com/pa0l0s/DU-Paolo-Combat-HUD/raw/master/dist/DU-Paolo-Combat-HUD-v28.zip)

Inside you'll find:

```
gunner_seat_hud.conf
remote_controller_hud.conf
INSTALL.txt
```

---

## 2. Copy the .conf files into Dual Universe

Put **both** `.conf` files into your DU **custom autoconf** folder:

```
%ProgramData%\Dual Universe\Game\data\lua\autoconf\custom\
```

If DU is installed somewhere custom, the folder is:

```
<your DU install>\Game\data\lua\autoconf\custom\
```

> **Tip:** paste `%ProgramData%\Dual Universe\Game\data\lua\autoconf\custom\` into the Windows Explorer address bar and press Enter. Create the `custom` folder if it doesn't exist.

If DU is already running, **fully restart the game client** so it re-scans the autoconf folder.

---

## 3. Wire your ship

The HUDs read from elements linked to each control unit. Use the **Link tool** (default **L**) to connect:

### Gunner seat
| Link the seat to… | Why |
|-------------------|-----|
| **Weapons** | Weapon states, reload bars, firing cone |
| **PVP Radar** | Target list, AR markers, target intel |
| **Databank** | Shares target data with the pilot |

### Remote controller
| Link the controller to… | Why |
|-------------------------|-----|
| **Shield generator** | Shield HP, resistances, venting, auto-resist |
| **Databank** (the **same** one as the gunner) | Receives shared data from the gunner |

### Fuel tanks
**Do not link anything.** Atmo / Space / Rocket fuel tanks are detected automatically — the HUD binds to all of them the same way the native fuel widget does.

> ✅ **Use a single databank linked to *both* the gunner seat and the remote controller.** That shared databank is what lets the two HUDs cooperate.

---

## 4. Apply the HUD (Autoconfigure)

For **each** control unit:

1. Right-click the element (gunner seat, then remote controller).
2. Choose **Advanced → Update custom autoconf**.
3. Pick the matching HUD:
   - Gunner seat → **Gunner Seat HUD (Retrosyncwave)**
   - Remote controller → **Remote Controller HUD (Retrosyncwave)**
4. The config **name includes the version** (e.g. `… v28`). Seeing `v28` confirms the new build loaded — handy after updates.

---

## 5. Verify

- **Gunner seat:** enter the seat — you should see the WEAPONS, target, and TELEMETRY panels. Weapons and radar behave like the native widgets.
- **Remote controller:** control the ship — the FLIGHT panel (with FUEL rows for the fuel types you carry), SHIELD panel, and move-direction marker should appear.
- Fly: **WASD** rotates, **mouse wheel** throttles, **Left Ctrl** toggles brakes, **Space** toggles SMOOTH/STABLE aim mode.

---

## 6. Tune it (optional)

Every setting is an in-game `--export`:

1. Right-click the control unit → **Advanced → Edit Lua parameters**.
2. Adjust values (rotation sensitivity, brake strength, fuel warning thresholds, warning sound, etc.).
3. Apply — no reinstall needed.

See the [Configuration table in the README](README.md#configuration) for every export and what it does.

---

## Updating to a newer version

1. Download the newer zip and overwrite the two `.conf` files in the `custom` folder.
2. Restart the DU client.
3. Re-run **Update custom autoconf** on each control unit.
4. Confirm the new version number in the config name.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| HUD doesn't appear in the autoconf list | `.conf` files aren't in the `custom` folder, or DU wasn't restarted after copying them. |
| Old version still showing | Re-run **Update custom autoconf**; check the version number in the config name. |
| No shield panel | The shield generator isn't linked to the remote controller. |
| No target / weapon info | Weapons and/or the PVP radar aren't linked to the gunner seat. |
| Fuel rows missing | Expected only if the ship has no fuel tanks; otherwise they auto-detect. |
| No warning sound | `warnSound` must name a file in `…/NQ/DualUniverse/audio`. Visual warnings work regardless. |
| Reload/weapon widget acts up until you switch view | Known DU quirk with weapon widgets; toggle to gunner view once. |
