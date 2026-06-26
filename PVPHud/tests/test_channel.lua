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

-- getJson must never hand out the shared schema default by reference.
-- Use ch2 (nil db) to ensure default path is taken, not the codec decode path.
local a = ch2.getJson("deadCores")
local b = ch2.getJson("deadCores")
T.ok(a ~= b, "getJson returns distinct tables per call")
a["x"] = 1
T.eq(#channel.schema.deadCores.default, 0, "schema default not mutated by caller")
T.eq(next(ch2.getJson("deadCores")), nil, "later getJson still empty after caller mutation")
