-- Pure flight telemetry math. No DU globals.
local M = {}

local G = 9.80665

-- Acceleration (m/s^2) -> g.
function M.toG(accelMps2)
  return accelMps2 / G
end

-- Stopping distance (metres) from speed (m/s), max brake force (N) and mass (kg).
-- distance = v^2 / (2 * a), a = brakeN / massKg. Returns 0 when inputs are unusable.
function M.brakeDistance(speedMps, maxBrakeN, massKg)
  if not maxBrakeN or maxBrakeN <= 0 or not massKg or massKg <= 0 then return 0 end
  local a = maxBrakeN / massKg
  return (speedMps * speedMps) / (2 * a)
end

-- Clamp a value/max into a 0..1 ratio (for bars). max<=0 -> 0.
function M.ratio(value, max)
  if not max or max <= 0 then return 0 end
  local r = value / max
  if r < 0 then return 0 end
  if r > 1 then return 1 end
  return r
end

return M
