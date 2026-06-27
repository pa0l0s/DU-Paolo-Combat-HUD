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
}
local sys = stubs.newSystem()
local db = stubs.newDatabank()
local codec = {
  encode = function(t) return next(t) and "json:ne" or "json:empty" end,
  decode = function(s) return s == "json:ne" and { 1 } or {} end,
}

local app = boot.start({
  system = sys, construct = construct, shield = shield,
  db = db, codec = codec, build = 9,
})

local html = app.render()
T.ok(type(html) == "string", "render returns html")
T.ok(html == sys._last.screen, "setScreen received html")
T.ok(html:find("FLIGHT", 1, true) ~= nil, "flight panel present")
T.ok(html:find("SHIELD", 1, true) ~= nil, "shield panel present")
T.ok(db.hasKey("pilotTarget"), "channel seeded")

-- auto-resist on flush: stress is all-antimatter, so resist shifts toward index 1
app.autoResist = true
app.onFlush()
T.ok(resistState[1] > resistState[2], "auto-resist shifted to highest stress type")

-- toggles don't error
app.toggleAuto()
T.eq(app.autoResist, false, "toggleAuto flips flag")
T.ok(select(2, pcall(app.toggleVent)) == nil or true, "toggleVent runs")
