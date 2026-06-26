-- Databank "bus" shared by the gunner and controller HUDs.
-- Pure: operates on an injected databank object + optional JSON codec.
local M = {}

-- Shallow copy of a schema default so callers never mutate the shared instance.
local function copyDefault(default)
  local c = {}
  for k, v in pairs(default) do c[k] = v end
  return c
end

-- key -> { kind = "int"|"json", default = value }
M.schema = {
  pilotTarget  = { kind = "int",  default = 0 },
  targetSpeed  = { kind = "int",  default = -1 },
  GunnerSystem = { kind = "int",  default = 0 },
  RedSquare    = { kind = "int",  default = 1 },
  GreenSquare  = { kind = "int",  default = 0 },
  YellowSquare = { kind = "int",  default = 1 },
  BlueSquare   = { kind = "int",  default = 1 },
  friendlist   = { kind = "json", default = {} },
  deadCores    = { kind = "json", default = {} },
}

-- Build a channel over a databank object. codec = {encode=,decode=} or nil.
function M.new(db, codec)
  local self = {}

  function self.seed()
    if not db then return end
    for key, spec in pairs(M.schema) do
      if not db.hasKey(key) then
        if spec.kind == "int" then
          db.setIntValue(key, spec.default)
        elseif codec then
          db.setStringValue(key, codec.encode(spec.default))
        end
      end
    end
  end

  function self.getInt(key)
    local spec = M.schema[key]
    if not db or not db.hasKey(key) then return spec.default end
    return db.getIntValue(key)
  end

  function self.setInt(key, value)
    if db then db.setIntValue(key, value) end
  end

  function self.getJson(key)
    local spec = M.schema[key]
    if not db or not codec or not db.hasKey(key) then
      return copyDefault(spec.default)
    end
    return codec.decode(db.getStringValue(key)) or copyDefault(spec.default)
  end

  function self.setJson(key, value)
    if db and codec then db.setStringValue(key, codec.encode(value)) end
  end

  return self
end

return M
