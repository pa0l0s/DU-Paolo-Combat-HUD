-- Thin adapter over a DU RadarPVPUnit. Returns plain tables.
local M = {}

function M.new(radar)
  local self = { radar = radar }

  function self.targetId() return self.radar.getTargetId() end
  function self.contacts() return self.radar.getConstructIds() end

  function self.info(id)
    local r = self.radar
    return {
      name = r.getConstructName(id),
      distance = r.getConstructDistance(id),
      speed = r.getConstructSpeed(id),
      mass = r.getConstructMass(id),
      coreSize = r.getConstructCoreSize(id),
      angular = r.getConstructAngularSpeed(id) * 180 / math.pi,
      identified = r.isConstructIdentified(id),
      abandoned = r.isConstructAbandoned(id),
      threatRate = r.getThreatRateFrom(id),
      transponder = r.hasMatchingTransponder(id),
      worldPos = r.getConstructWorldPos(id),
    }
  end

  return self
end

return M
