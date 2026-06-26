local duShield = require("du.shield")
local duFlight = require("du.flight")

-- nil shield tolerated
local empty = duShield.new(nil)
T.eq(empty.present(), false, "nil shield not present")
T.eq(empty.hpPct(), 0, "nil shield hp 0")

local shield = {
  getShieldHitpoints = function() return 750 end,
  getMaxShieldHitpoints = function() return 1000 end,
  getResistances = function() return { 0.2, 0.2, 0.2, 0.2 } end,
  getResistancesPool = function() return 1.0 end,
  getResistancesCooldown = function() return 0 end,
  getStressRatioRaw = function() return { 0.5, 0.5, 0, 0 } end,
  isVenting = function() return false end,
  getVentingCooldown = function() return 5 end,
  setResistances = function() return true end,
  startVenting = function() return true end,
  stopVenting = function() return true end,
}
local S = duShield.new(shield)
T.eq(S.present(), true, "shield present")
T.ok(math.abs(S.hpPct() - 0.75) < 1e-9, "hp pct = hp/max")
T.eq(S.pool(), 1.0, "pool passthrough")
T.eq(S.cooldown(), 0, "cooldown passthrough")
T.eq(S.stressRatio()[1], 0.5, "stress ratio passthrough")
T.eq(S.ventCooldown(), 5, "vent cooldown passthrough")
T.eq(S.isVenting(), false, "isVenting passthrough")
T.eq(S.setResistances(1, 0, 0, 0), true, "setResistances passthrough")

-- flight from construct velocity/mass
local construct = {
  getWorldVelocity = function() return { 3, 4, 0 } end, -- |v| = 5
  getMass = function() return 42000 end,
}
local F = duFlight.new(construct)
T.ok(math.abs(F.speed() - 5) < 1e-9, "speed = |velocity|")
T.eq(F.mass(), 42000, "mass passthrough")
