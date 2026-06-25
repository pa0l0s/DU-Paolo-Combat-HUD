-- Stub DU globals for desktop testing. No DU runtime needed.
local M = {}

local vmt = {}; vmt.__index = vmt
local function vec3(x, y, z)
  if type(x) == "table" then x, y, z = x[1] or x.x, x[2] or x.y, x[3] or x.z end
  return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, vmt)
end
function vmt.__sub(a, b) return vec3(a.x - b.x, a.y - b.y, a.z - b.z) end
function vmt.__add(a, b) return vec3(a.x + b.x, a.y + b.y, a.z + b.z) end
function vmt:len() return math.sqrt(self.x^2 + self.y^2 + self.z^2) end
function vmt:normalize()
  local l = self:len(); if l == 0 then return vec3(0, 0, 0) end
  return vec3(self.x / l, self.y / l, self.z / l)
end
M.vec3 = vec3

function M.newDatabank(initial)
  local store = {}
  for k, v in pairs(initial or {}) do store[k] = v end
  return {
    hasKey = function(k) return store[k] ~= nil end,
    getIntValue = function(k) return tonumber(store[k]) or 0 end,
    setIntValue = function(k, v) store[k] = v end,
    getStringValue = function(k) return tostring(store[k] or "") end,
    setStringValue = function(k, v) store[k] = v end,
    _store = store,
  }
end

function M.newSystem()
  local last = { screen = nil, prints = {} }
  return {
    setScreen = function(html) last.screen = html end,
    showScreen = function() end,
    print = function(m) table.insert(last.prints, m) end,
    getScreenWidth = function() return 1920 end,
    getScreenHeight = function() return 1080 end,
    getUtcTime = function() return 0 end,
    _last = last,
  }
end

return M
