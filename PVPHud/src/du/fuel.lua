-- Thin adapter over DU fuel container elements. Fuel tanks auto-bind to a control
-- unit (like the native fuel widget) via `select: all` slots -- no manual link.
-- Each tank's getWidgetData() is the game's own precise reading: JSON with
-- `percentage` (0..100) and `timeLeft` (seconds). Reads are guarded so a missing
-- tank, missing decoder, or malformed data degrades to "no reading" not a crash.
local M = {}

local function readTank(elem, decode)
  local ok, raw = pcall(function() return elem.getWidgetData() end)
  if not ok or type(raw) ~= "string" then return nil end
  local okd, data = pcall(decode, raw)
  if not okd or type(data) ~= "table" then return nil end
  local pct = tonumber(data.percentage)
  return {
    level = pct and (pct / 100) or 0,
    timeLeft = tonumber(data.timeLeft),
  }
end

-- groups = { atmo = <elem array|nil>, space = <...>, rocket = <...> }
-- decode = a json.decode(string) -> table function.
function M.new(groups, decode)
  local self = { groups = groups or {}, decode = decode }

  local function readGroup(arr)
    local out = {}
    if type(arr) == "table" and self.decode then
      for _, e in ipairs(arr) do
        if e and e.getWidgetData then
          local r = readTank(e, self.decode)
          if r then out[#out + 1] = r end
        end
      end
    end
    return out
  end

  function self.atmo() return readGroup(self.groups.atmo) end
  function self.space() return readGroup(self.groups.space) end
  function self.rocket() return readGroup(self.groups.rocket) end

  return self
end

return M
