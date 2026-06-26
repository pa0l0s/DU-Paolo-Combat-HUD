-- Thin adapter over DU construct world->screen projection. Returns plain tables.
local M = {}

function M.new(construct)
  local self = { construct = construct }

  -- pos {x,y,z} -> {x,y} screen pixels, or nil if behind the camera.
  function self.toScreen(pos, screenW, screenH)
    local p = self.construct.getPointOnScreen({ pos.x, pos.y, pos.z })
    if not p then return nil end
    if p[3] ~= nil and p[3] <= 0 then return nil end
    return { x = p[1] * screenW, y = p[2] * screenH }
  end

  return self
end

return M
