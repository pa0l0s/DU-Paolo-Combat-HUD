-- Pure dynamic auto-resist allocation. No DU globals.
-- stressRatio: 1..4 array of incoming-damage fractions (DU getStressRatioRaw order:
-- antimatter, electromagnetic, kinetic, thermic). pool: total resistance points.
local M = {}

function M.allocate(stressRatio, pool)
  local out = {}
  for i = 1, 4 do out[i] = (stressRatio[i] or 0) * pool end
  return out
end

-- True when any component of newRes differs from current by more than eps.
function M.shouldUpdate(newRes, current, eps)
  eps = eps or 1
  for i = 1, 4 do
    if math.abs((newRes[i] or 0) - (current[i] or 0)) > eps then return true end
  end
  return false
end

-- True when no meaningful incoming stress (all four ~0).
function M.isZero(stressRatio)
  for i = 1, 4 do
    if math.abs(stressRatio[i] or 0) > 1e-6 then return false end
  end
  return true
end

return M
