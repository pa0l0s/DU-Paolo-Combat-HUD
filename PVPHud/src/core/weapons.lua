-- Pure weapon status -> display mapping. No DU globals.
-- Status codes (DU WeaponUnit): 1 IDLE, 2 FIRING, 4 RELOADING, 5 UNLOADING, 6 BLOCKED.
local M = {}

function M.describe(raw)
  local s = raw.status
  local ammo = raw.ammoPct or 0
  if not raw.operational then return { label = "BROKEN", role = "threat", barPct = 0 } end
  if s == 4 then return { label = "RELOADING", role = "caution", barPct = 1 } end
  if s == 5 then return { label = "UNLOADING", role = "caution", barPct = 1 } end
  if ammo <= 0 then return { label = "RELOAD", role = "threat", barPct = 0 } end
  if s == 6 then return { label = "BLOCKED", role = "threat", barPct = ammo } end
  if ammo <= 0.1 then return { label = "LOW AMMO", role = "caution", barPct = ammo } end
  if s == 2 then return { label = "FIRING", role = "ready", barPct = ammo } end
  if s == 1 then return { label = "IDLE", role = "base", barPct = ammo } end
  return { label = "ERROR", role = "threat", barPct = ammo }
end

return M
