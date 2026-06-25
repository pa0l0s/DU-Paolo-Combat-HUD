-- Pure number/distance/speed formatting. No DU globals.
local M = {}

-- 1234567 -> "1,234,567" (handles negatives).
function M.groupThousands(n)
  local s = tostring(math.floor(n))
  local sign = ""
  if s:sub(1, 1) == "-" then sign = "-"; s = s:sub(2) end
  while true do
    local r
    s, r = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
    if r == 0 then break end
  end
  return sign .. s
end

-- metres -> m / km / su (1 su = 200 km).
function M.distance(m)
  if m < 1000 then
    return math.ceil(m) .. "m"
  elseif m < 100000 then
    return string.format("%.1fkm", m / 1000)
  else
    return string.format("%.2fsu", m / 200000)
  end
end

-- m/s -> "12,345 km/h". nil -> "".
function M.speed(mps)
  if mps == nil then return "" end
  return M.groupThousands(math.floor(mps * 3.6)) .. " km/h"
end

-- 1500 -> "1.5k", 2300000 -> "2.3m".
function M.compact(n)
  if n < 1000 then
    return tostring(math.floor(n))
  elseif n < 1000000 then
    return string.format("%.1fk", n / 1000)
  else
    return string.format("%.1fm", n / 1000000)
  end
end

return M
