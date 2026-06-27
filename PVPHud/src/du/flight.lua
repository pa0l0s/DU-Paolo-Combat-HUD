-- Thin adapter over DU flight data (construct + control unit). Returns plain numbers.
-- Reads are guarded so a missing/renamed API degrades to 0 instead of crashing.
local M = {}

local G = 9.80665
local LONG_TAGS = 'thrust analog longitudinal'

local function vlen(v)
  if type(v) ~= 'table' then return 0 end
  local x, y, z = v[1] or 0, v[2] or 0, v[3] or 0
  return math.sqrt(x * x + y * y + z * z)
end

local function num(fn)
  local ok, r = pcall(fn)
  if ok and type(r) == 'number' then return r end
  return 0
end

function M.new(construct, unit)
  local self = { construct = construct, unit = unit }

  function self.speed()
    return vlen(self.construct.getWorldVelocity())
  end

  function self.mass() return self.construct.getMass() end

  -- Output acceleration magnitude in g.
  function self.accelG()
    return num(function() return vlen(self.construct.getWorldAcceleration()) end) / G
  end

  -- Commanded throttle percentage (-100..100). 0 without a control unit.
  function self.throttlePct()
    if not self.unit then return 0 end
    return num(function() return self.unit.getThrottle() end)
  end

  -- Max brake force (N).
  function self.maxBrake()
    return num(function() return self.construct.getMaxBrake() end)
  end

  -- Actual longitudinal engine output as 0..1 of max (shows the warm-up ramp).
  function self.engineRatio()
    if not self.unit then return 0 end
    local cur = num(function() return vlen(self.unit.getEngineThrust(LONG_TAGS)) end)
    local maxN = 0
    pcall(function()
      local mt = self.construct.getMaxThrustAlongAxis(LONG_TAGS, self.construct.getOrientationForward())
      if type(mt) == 'table' then
        for _, v in ipairs(mt) do
          if type(v) == 'number' and v > maxN then maxN = v end
        end
      end
    end)
    if maxN <= 0 then return 0 end
    local r = cur / maxN
    if r < 0 then return 0 elseif r > 1 then return 1 end
    return r
  end

  return self
end

return M
