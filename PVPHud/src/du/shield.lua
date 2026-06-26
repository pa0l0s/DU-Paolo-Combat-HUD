-- Thin adapter over a DU ShieldGeneratorUnit. Tolerates a nil shield.
local M = {}

function M.new(shield)
  local self = { shield = shield }

  function self.present() return self.shield ~= nil end

  function self.hpPct()
    if not self.shield then return 0 end
    local mx = self.shield.getMaxShieldHitpoints()
    if mx <= 0 then return 0 end
    return self.shield.getShieldHitpoints() / mx
  end

  function self.resistances() return self.shield.getResistances() end
  function self.pool() return self.shield.getResistancesPool() end
  function self.cooldown() return self.shield.getResistancesCooldown() end
  function self.stressRatio() return self.shield.getStressRatioRaw() end
  function self.isVenting() return self.shield.isVenting() end
  function self.ventCooldown() return self.shield.getVentingCooldown() end
  function self.setResistances(a, e, k, t) return self.shield.setResistances(a, e, k, t) end
  function self.startVenting() return self.shield.startVenting() end
  function self.stopVenting() return self.shield.stopVenting() end

  return self
end

return M
