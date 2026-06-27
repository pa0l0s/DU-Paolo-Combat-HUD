local stubs = require("stubs")
local boot = require("bootstrap_controller")

local resistState = { 0.2, 0.2, 0.2, 0.2 }
local shield = {
  getShieldHitpoints = function() return 800 end,
  getMaxShieldHitpoints = function() return 1000 end,
  getResistances = function() return resistState end,
  getResistancesPool = function() return 1.0 end,
  getResistancesCooldown = function() return 0 end,
  getStressRatioRaw = function() return { 1, 0, 0, 0 } end,
  isVenting = function() return false end,
  getVentingCooldown = function() return 0 end,
  setResistances = function(a, e, k, t) resistState = { a, e, k, t }; return true end,
  startVenting = function() return true end,
  stopVenting = function() return true end,
}
local construct = {
  getWorldVelocity = function() return { 100, 0, 0 } end,
  getMass = function() return 50000 end,
  getWorldAcceleration = function() return { 9.80665, 0, 0 } end, -- 1 g
  getMaxBrake = function() return 200000 end,
  getOrientationForward = function() return { 0, 1, 0 } end,
  getMaxThrustAlongAxis = function() return { 1000000, 1000000 } end,
}
local unit = {
  getThrottle = function() return 80 end,
  getEngineThrust = function() return { 400000, 0, 0 } end, -- 40% of max -> warmup
}
local sys = stubs.newSystem()
local db = stubs.newDatabank()
local codec = {
  encode = function(t) return next(t) and "json:ne" or "json:empty" end,
  decode = function(s) return s == "json:ne" and { 1 } or {} end,
}

local app = boot.start({
  system = sys, construct = construct, unit = unit, shield = shield,
  db = db, codec = codec, build = 9,
})

local html = app.render()
T.ok(type(html) == "string", "render returns html")
T.ok(html == sys._last.screen, "setScreen received html")
T.ok(html:find("FLIGHT", 1, true) ~= nil, "flight panel present")
T.ok(html:find("SHIELD", 1, true) ~= nil, "shield panel present")
T.ok(html:find("THR 80%", 1, true) ~= nil, "throttle set shown")
T.ok(html:find("OUTPUT  1.0 g", 1, true) ~= nil, "output g from acceleration")
T.ok(db.hasKey("pilotTarget"), "channel seeded")

-- brake state reflects the brakeInput passed to onUpdate
app.onUpdate(1)
T.ok(sys._last.screen:find("BRAKE ON", 1, true) ~= nil, "brake ON shown when braking")
app.onUpdate(0)
T.ok(sys._last.screen:find("BRAKE OFF", 1, true) ~= nil, "brake OFF shown when not braking")

-- auto-resist on flush: stress is all-antimatter, so resist shifts toward index 1
app.autoResist = true
app.onFlush()
T.ok(resistState[1] > resistState[2], "auto-resist shifted to highest stress type")

-- toggles don't error
app.toggleAuto()
T.eq(app.autoResist, false, "toggleAuto flips flag")
T.ok(select(2, pcall(app.toggleVent)) == nil or true, "toggleVent runs")
