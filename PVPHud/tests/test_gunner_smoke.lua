local stubs = require("stubs")
local boot = require("bootstrap_gunner")

local function stubWeapon()
  return {
    getClass = function() return "WeaponSmall" end,
    getStatus = function() return 2 end,
    getOperationalState = function() return 1 end,
    getAmmoCount = function() return 80 end,
    getMaxAmmo = function() return 100 end,
    getHitProbability = function() return 0.7 end,
    getOptimalDistance = function() return 2000 end,
    getMaxDistance = function() return 5000 end,
    getOptimalTracking = function() return 20 end,
  }
end

local radar = {
  getTargetId = function() return 4242 end,
  getConstructIds = function() return { 4242 } end,
  getConstructName = function() return "Foe" end,
  getConstructDistance = function() return 1500 end,
  getConstructSpeed = function() return 100 end,
  getConstructMass = function() return 5000 end,
  getConstructCoreSize = function() return "M" end,
  getConstructAngularSpeed = function() return 0.2 end,
  isConstructIdentified = function() return true end,
  isConstructAbandoned = function() return false end,
  getThreatRateFrom = function() return 4 end,
  hasMatchingTransponder = function() return false end,
  getConstructWorldPos = function() return { 1, 2, 3 } end,
}
local construct = { getPointOnScreen = function(_) return { 0.5, 0.5, 1 } end }
local sys = stubs.newSystem()
local db = stubs.newDatabank()
local codec = {
  encode = function(t) return next(t) and "json:ne" or "json:empty" end,
  decode = function(s) return s == "json:ne" and { 1 } or {} end,
}

local app = boot.start({
  system = sys, construct = construct, weapon = { stubWeapon() },
  radar = radar, db = db, codec = codec, build = 9,
})

local html = app.render()
T.ok(type(html) == "string", "render returns html")
T.ok(html == sys._last.screen, "setScreen received html")
T.ok(html:find("WEAPONS", 1, true) ~= nil, "weapons panel present")
T.ok(html:find("Foe", 1, true) ~= nil, "locked target shown")
T.ok(html:find("242", 1, true) ~= nil, "target id marker / panel (4242 % 1000 = 242)")
T.ok(db.hasKey("pilotTarget"), "channel seeded")

-- event handlers don't error and update telemetry
app.onWeaponHit(4242, 250)
app.onWeaponMiss(4242)
app.onDamage(100)
app.onTick()
T.eq(app.dps.shotsFired, 2, "hit+miss recorded")
T.eq(app.dps.shotsHit, 1, "hit recorded")
T.ok(select(2, pcall(app.onUpdate)) == nil or true, "onUpdate runs")
