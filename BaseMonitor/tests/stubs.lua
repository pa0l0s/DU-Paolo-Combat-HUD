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

return stubs
