-- Pure PvP weapon math. No DU globals.
local M = {}

-- Distance color band vs a weapon's optimal range and spread.
function M.rangeBand(distance, optimal, spread)
  if distance <= optimal then return "ready"
  elseif distance <= optimal + spread then return "caution"
  else return "threat" end
end

-- Half the gap between optimal and max distance.
function M.spread(maxDistance, optimalDistance)
  return (maxDistance - optimalDistance) / 2
end

-- Angular-speed (deg/s) band vs a weapon's optimal tracking.
function M.angularBand(angular, optimalTracking)
  if optimalTracking <= 0 then return "threat" end
  if angular <= optimalTracking then return "ready"
  elseif angular <= optimalTracking * 2 then return "caution"
  else return "threat" end
end

-- Hit-probability (0..100) band.
function M.hitBand(hitPct)
  if hitPct >= 70 then return "ready"
  elseif hitPct >= 30 then return "caution"
  else return "threat" end
end

-- Max attainable speed (m/s) for a target of given mass (kg).
-- DU PvP speed-vs-mass curve; clamped between 20000 and 50000 km/h.
function M.maxTargetSpeed(massKg)
  local hi = 50000 / 3.6
  local lo = 20000 / 3.6
  local v = hi - 10713 * (massKg - 10000) / (853926 + massKg - 10000)
  return math.max(math.min(hi, v), lo)
end

return M
