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
    getContent     = function() return opts.content end,
    updateContent  = function() return 0 end,
  }
end

-- A fake screen handle (render-script API + legacy setHTML).
function stubs.screen()
  local self = { html = nil, rs = nil, input = nil, activated = false }
  self.setHTML         = function(h) self.html = h end
  self.setRenderScript = function(s) self.rs = s end
  self.setScriptInput  = function(i) self.input = i end
  self.activate        = function() self.activated = true end
  self.getClass        = function() return "ScreenUnit" end
  return self
end

-- Installs fake DU globals (slot1..slotN, system, unit) for bootstrap tests.
-- In standard Lua _G == _ENV, so setting _G.slotN also makes the bare global slotN
-- resolve -- matching how the shipped code reads slots by direct name.
-- spec: { slots = { handle|screen, ... } }  -- linked into slot1..slotN in order
function stubs.installGlobals(spec)
  _G.system = {
    print = function() end,
    _hud = nil, _shown = false,
    setScreen = function(h) _G.system._hud = h end,
    showScreen = function(b) _G.system._shown = true end,
  }
  _G.unit = { _timers = {}, setTimer = function(tag, s) _G.unit._timers[tag] = s end }
  for i = 1, 10 do _G["slot" .. i] = nil end
  for i, s in ipairs(spec.slots or {}) do _G["slot" .. i] = s end
end

return stubs
