-- Thin adapter over DU construct flight data. Returns plain numbers.
local M = {}

function M.new(construct)
  local self = { construct = construct }

  function self.speed()
    local v = self.construct.getWorldVelocity()
    return math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
  end

  function self.mass() return self.construct.getMass() end

  return self
end

return M
