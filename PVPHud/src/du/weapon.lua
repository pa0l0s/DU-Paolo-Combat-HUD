-- Thin adapter over a DU WeaponUnit array. Returns plain tables.
local M = {}

function M.new(weapons)
  local self = { weapons = weapons or {} }

  function self.count() return #self.weapons end

  function self.readings()
    local out = {}
    for i, w in ipairs(self.weapons) do
      local maxAmmo = w.getMaxAmmo()
      out[i] = {
        class = (w.getClass():match("Weapon(%a)")) or "?",
        status = w.getStatus(),
        operational = w.getOperationalState() == 1,
        ammoPct = (maxAmmo > 0) and (w.getAmmoCount() / maxAmmo) or 0,
        hitProbability = w.getHitProbability(),
      }
    end
    return out
  end

  function self.firstSpec()
    local w = self.weapons[1]
    if not w then return nil end
    return {
      optimalDistance = w.getOptimalDistance(),
      maxDistance = w.getMaxDistance(),
      optimalTracking = w.getOptimalTracking(),
      aimingCone = w.getOptimalAimingCone and w.getOptimalAimingCone() or 0,
    }
  end

  return self
end

return M
