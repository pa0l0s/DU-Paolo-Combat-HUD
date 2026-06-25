local stubs = require("stubs")
local channel = require("core.channel")

local codec = {
  encode = function(t) return next(t) and "json:ne" or "json:empty" end,
  decode = function(s) return s == "json:ne" and { 1 } or {} end,
}

local db = stubs.newDatabank()
local ch = channel.new(db, codec)

-- defaults apply before seeding
T.eq(ch.getInt("pilotTarget"), 0, "default pilotTarget")
T.eq(ch.getInt("targetSpeed"), -1, "default targetSpeed")

ch.seed()
T.ok(db.hasKey("RedSquare"), "seed creates int key")
T.eq(db.getIntValue("RedSquare"), 1, "seed default value")

ch.setInt("pilotTarget", 123)
T.eq(ch.getInt("pilotTarget"), 123, "int set/get roundtrip")

ch.setJson("friendlist", { 1 })
T.eq(#ch.getJson("friendlist"), 1, "json roundtrip via codec")

-- nil db is tolerated (HUD runs without a databank)
local ch2 = channel.new(nil, nil)
T.eq(ch2.getInt("GunnerSystem"), 0, "nil db returns default")
