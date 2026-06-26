-- Pure AR position memory: caches world positions, estimates velocity,
-- extrapolates when contact is lost, remembers dead-core positions.
-- Plain {x,y,z} tables; no DU globals, no vec3 dependency.
local M = {}

local function sub(a, b) return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z } end
local function add(a, b) return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z } end
local function scale(a, s) return { x = a.x * s, y = a.y * s, z = a.z * s } end

function M.new()
  local self = { live = {}, dead = {} }

  function self.update(id, pos, t)
    local prev = self.live[id]
    local vel = prev and prev.vel or nil
    if prev then
      local dt = t - prev.t
      if dt > 0 then vel = scale(sub(pos, prev.pos), 1 / dt) end
    end
    self.live[id] = { pos = { x = pos.x, y = pos.y, z = pos.z }, t = t, vel = vel }
  end

  function self.predict(id, t)
    local e = self.live[id]
    if not e then return nil end
    if e.vel then return add(e.pos, scale(e.vel, t - e.t)) end
    return { x = e.pos.x, y = e.pos.y, z = e.pos.z }
  end

  function self.forget(id) self.live[id] = nil end

  function self.markDead(id, pos)
    self.dead[id] = { x = pos.x, y = pos.y, z = pos.z }
  end

  function self.deadCores()
    local out = {}
    for id, pos in pairs(self.dead) do out[id] = pos end
    return out
  end

  function self.clearDead() self.dead = {} end

  return self
end

return M
