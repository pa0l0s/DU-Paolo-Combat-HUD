-- Thin adapter over DU world->screen projection. Returns plain tables.
-- NOTE: getPointOnScreen lives on the `library` global in DU (not `construct`
-- and not `system`) -- confirmed via the official api-mockup + GFL/ArchHUD HUDs.
-- The caller passes that projector object to new().
local M = {}

function M.new(projector)
  local self = { projector = projector }

  -- pos {x,y,z} -> {x,y} screen pixels, or nil if behind the camera or if no
  -- projector is available (degrade gracefully rather than crash).
  function self.toScreen(pos, screenW, screenH)
    local proj = self.projector
    if not proj or not proj.getPointOnScreen then return nil end
    local p = proj.getPointOnScreen({ pos.x, pos.y, pos.z })
    if not p then return nil end
    if p[3] ~= nil and p[3] <= 0 then return nil end
    return { x = p[1] * screenW, y = p[2] * screenH }
  end

  return self
end

return M
