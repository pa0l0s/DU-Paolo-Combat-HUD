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

local MAX_SLOTS = 24

local function readContainer(c, getName)
  local localId = nil
  pcall(function() localId = c.getLocalId() end)
  local label = (localId and getName and getName(localId)) or nil

  local vol = c.getItemsVolume()
  local maxVol = c.getMaxVolume()
  local mass = c.getItemsMass()

  if not label then label = "Container " .. tostring(localId or "?") end
  local pct = 0
  if maxVol and maxVol > 0 then pct = (vol / maxVol) * 100 end
  return { label = label, vol = vol or 0, maxVol = maxVol or 0,
           mass = mass or 0, pct = pct, ok = true }
end

function M.buildRows(slots, getName)
  local rows = {}
  for i = 1, MAX_SLOTS do
    local c = slots[i]
    if c ~= nil then
      local ok, row = pcall(readContainer, c, getName)
      if ok then
        rows[#rows + 1] = row
      else
        -- Best-effort label even on failure.
        local localId = nil
        pcall(function() localId = c.getLocalId() end)
        local label = (localId and getName and getName(localId)) or ("Container " .. tostring(localId or "?"))
        rows[#rows + 1] = { label = label, vol = 0, maxVol = 0, mass = 0, pct = 0, ok = false }
      end
    end
  end
  return rows
end

return M
