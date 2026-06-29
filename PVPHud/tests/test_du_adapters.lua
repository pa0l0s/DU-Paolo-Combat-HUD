local duWeapon = require("du.weapon")
local duRadar = require("du.radar")
local duConstruct = require("du.construct")

-- stub WeaponUnit
local function stubWeapon(o)
  return {
    getClass = function() return "WeaponSmall" end,
    getStatus = function() return o.status end,
    getOperationalState = function() return o.op end,
    getAmmoCount = function() return o.ammo end,
    getMaxAmmo = function() return o.maxAmmo end,
    getHitProbability = function() return o.hit end,
    getOptimalDistance = function() return 2000 end,
    getMaxDistance = function() return 5000 end,
    getOptimalTracking = function() return 20 end,
    getOptimalAimingCone = function() return 5 end,
  }
end

local W = duWeapon.new({ stubWeapon({ status = 2, op = 1, ammo = 80, maxAmmo = 100, hit = 0.7 }) })
T.eq(W.count(), 1, "weapon count")
local r = W.readings()[1]
T.eq(r.class, "S", "class letter parsed from WeaponSmall")
T.eq(r.operational, true, "operational from state==1")
T.ok(math.abs(r.ammoPct - 0.8) < 1e-9, "ammoPct = ammo/maxAmmo")
T.eq(W.firstSpec().optimalDistance, 2000, "firstSpec optimal distance")
T.eq(W.firstSpec().aimingCone, 5, "firstSpec aiming cone")

-- stub RadarPVPUnit
local radar = {
  getTargetId = function() return 4242 end,
  getConstructIds = function() return { 4242 } end,
  getConstructName = function() return "Foe" end,
  getConstructDistance = function() return 1500 end,
  getConstructSpeed = function() return 100 end,
  getConstructMass = function() return 5000 end,
  getConstructCoreSize = function() return "M" end,
  getConstructAngularSpeed = function() return math.pi end, -- 180 deg/s
  isConstructIdentified = function() return true end,
  isConstructAbandoned = function() return false end,
  getThreatRateFrom = function() return 4 end,
  hasMatchingTransponder = function() return false end,
  getConstructWorldPos = function() return { 1, 2, 3 } end,
}
local R = duRadar.new(radar)
T.eq(R.targetId(), 4242, "target id")
T.eq(#R.contacts(), 1, "contacts list")
local info = R.info(4242)
T.eq(info.name, "Foe", "info name")
T.ok(math.abs(info.angular - 180) < 1e-6, "angular converted rad/s -> deg/s")
T.eq(info.worldPos[3], 3, "world pos passthrough")

-- stub construct projection
local construct = { getPointOnScreen = function(_) return { 0.5, 0.25, 1 } end }
local C = duConstruct.new(construct)
local scr = C.toScreen({ x = 1, y = 2, z = 3 }, 1920, 1080)
T.ok(math.abs(scr.x - 960) < 1e-6 and math.abs(scr.y - 270) < 1e-6, "projected to screen px")
local behind = duConstruct.new({ getPointOnScreen = function(_) return { 0.5, 0.5, -1 } end })
T.eq(behind.toScreen({ x = 0, y = 0, z = 0 }, 1920, 1080), nil, "behind camera -> nil")
