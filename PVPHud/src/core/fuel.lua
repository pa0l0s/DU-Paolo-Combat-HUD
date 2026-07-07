-- Pure fuel aggregation + low-fuel logic. No DU globals.
-- A "reading" is { level = 0..1, timeLeft = seconds|nil } for one tank.
local M = {}

-- Collapse a type's tank readings into one summary:
--   level    = average fill across tanks (0..1)
--   timeLeft = worst-case (minimum) burn time in seconds, or nil if unknown
--   count    = number of tanks, present = count > 0
function M.aggregate(tanks)
  if type(tanks) ~= "table" or #tanks == 0 then
    return { present = false, count = 0, level = 0 }
  end
  local sum, tmin = 0, nil
  for _, t in ipairs(tanks) do
    local lvl = t.level or 0
    if lvl < 0 then lvl = 0 elseif lvl > 1 then lvl = 1 end
    sum = sum + lvl
    local tl = t.timeLeft
    if tl and tl > 0 then
      if not tmin or tl < tmin then tmin = tl end
    end
  end
  return { present = true, count = #tanks, level = sum / #tanks, timeLeft = tmin }
end

-- Low when the fill is at/below levelThresh (0..1) OR a known burn time is
-- at/below timeThresh seconds.
function M.isLow(agg, levelThresh, timeThresh)
  if not agg or not agg.present then return false end
  if agg.level <= levelThresh then return true end
  if agg.timeLeft and agg.timeLeft <= timeThresh then return true end
  return false
end

return M
