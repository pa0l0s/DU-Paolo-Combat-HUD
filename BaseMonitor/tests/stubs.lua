-- DU global stubs + fake handles for local tests.
local stubs = {}

-- A fake container/hub handle.
-- opts: {vol, maxVol, mass, name, class, throw}
--   class defaults to "ItemContainerXL" (matches "Container"); throw=true makes reads error.
function stubs.handle(opts)
  return {
    getItemsVolume = function() if opts.throw then error("boom") end return opts.vol end,
    getMaxVolume   = function() return opts.maxVol end,
    getItemsMass   = function() return opts.mass end,
    getName        = function() return opts.name end,
    getClass       = function() return opts.class or "ItemContainerXL" end,
  }
end

-- A fake screen handle.
function stubs.screen()
  local self = { last = nil, activated = false }
  self.setHTML  = function(h) self.last = h end
  self.activate = function() self.activated = true end
  self.getClass = function() return "ScreenUnit" end
  return self
end

-- Installs fake DU globals (slot1..slotN, system, unit, exports) for bootstrap tests.
-- spec: {
--   slots   = { handle|screen, ... }   -- linked into slot1..slotN in order
--   exports = { refreshSeconds=.., warnPct=.., ... }
-- }
function stubs.installGlobals(spec)
  _G.system = { print = function() end }
  _G.unit = { _timers = {}, setTimer = function(tag, s) _G.unit._timers[tag] = s end }
  for i = 1, 10 do _G["slot" .. i] = nil end
  for i, s in ipairs(spec.slots or {}) do _G["slot" .. i] = s end
  -- Clear any stale export globals from a previous install, then apply.
  for _, k in ipairs({"refreshSeconds","warnPct","critPct","sortMode","title"}) do _G[k] = nil end
  for k, v in pairs(spec.exports or {}) do _G[k] = v end
end

return stubs
