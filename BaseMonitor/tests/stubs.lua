-- DU global stubs + fake handles (populated in later tasks).
local stubs = {}

-- A fake container handle. opts: {vol, maxVol, mass, id, throw}
function stubs.handle(opts)
  return {
    getItemsVolume = function() if opts.throw then error("boom") end return opts.vol end,
    getMaxVolume   = function() return opts.maxVol end,
    getItemsMass   = function() return opts.mass end,
    getLocalId     = function() return opts.id end,
  }
end

-- A name resolver backed by a {id=name} map.
function stubs.namer(map)
  return function(id) return map[id] end
end

function stubs.screen()
  local self = { last = nil }
  self.setHTML = function(h) self.last = h end
  return self
end

function stubs.core(nameMap)
  return { getElementNameById = function(id) return nameMap[id] end }
end

-- Installs fake DU globals into the global env for bootstrap tests.
-- spec: {names={id=name}, containers={ {vol,maxVol,mass,id}, ... }, exports={...} }
function stubs.installGlobals(spec)
  _G.core = stubs.core(spec.names or {})
  _G.screen = stubs.screen()
  _G.system = { print = function() end }
  _G.unit = { _timers = {}, setTimer = function(tag, s) _G.unit._timers[tag] = s end }
  for i = 1, 24 do _G["container" .. i] = nil end
  for i, c in ipairs(spec.containers or {}) do _G["container" .. i] = stubs.handle(c) end
  for k, v in pairs(spec.exports or {}) do _G[k] = v end
end

return stubs
