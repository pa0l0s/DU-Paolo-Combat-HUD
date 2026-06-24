-- Base Inventory Monitor (Dual Universe) -- single source of truth.
-- Pure logic + DU bootstrap. Exposes global BIM so local tests can reach it.
BIM = BIM or {}
local M = BIM

-- (functions added in later tasks)

local function round1(n) return math.floor(n * 10 + 0.5) / 10 end

function M.formatVolume(liters)
  liters = liters or 0
  if liters < 1000 then return string.format("%d L", math.floor(liters + 0.5)) end
  if liters < 1000000 then return string.format("%s kL", round1(liters / 1000)) end
  if liters < 1000000000 then return string.format("%s ML", round1(liters / 1000000)) end
  return string.format("%s GL", round1(liters / 1000000000))
end

function M.formatMass(kg)
  return string.format("%.1f t", (kg or 0) / 1000)
end

function M.formatPct(pct)
  pct = pct or 0
  if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
  return string.format("%d%%", math.floor(pct + 0.5))
end

return M
