local cv = require("render.controller_view")

local base = {
  screenW = 1920, screenH = 1080, css = "<style>Z</style>",
  flight = {
    speed = "1,200 km/h", mass = "420 t", maxSpeed = "30,000 km/h",
    throttleStr = "80%", throttleBar = 0.8, throttleRole = "ready",
    engineRatio = 0.4, outputG = "1.2 g",
    brakeState = "BRAKE OFF", brakeRole = "base", brakeDist = "1.2km",
    rotMode = "SMOOTH", rotRole = "caution",
  },
  shield = nil, markersSvg = "",
}

local noShield = cv.build(base)
T.ok(noShield:find("<style>Z</style>", 1, true) ~= nil, "includes css")
T.ok(noShield:find("<svg", 1, true) ~= nil, "opens svg")
T.ok(noShield:find("</svg>", 1, true) ~= nil, "closes svg")
T.ok(noShield:find("FLIGHT", 1, true) ~= nil, "flight header")
T.ok(noShield:find("1,200 km/h", 1, true) ~= nil, "speed shown")
T.ok(noShield:find("THR 80%", 1, true) ~= nil, "throttle set shown")
T.ok(noShield:find("OUTPUT  1.2 g", 1, true) ~= nil, "output g shown")
T.ok(noShield:find("BRAKE OFF", 1, true) ~= nil, "brake state shown")
T.ok(noShield:find("DIST 1.2km", 1, true) ~= nil, "brake distance shown")
T.ok(noShield:find("SMOOTH", 1, true) ~= nil, "rotation mode shown")

local withShield = {}
for k, v in pairs(base) do withShield[k] = v end
withShield.shield = {
  hpPct = 0.75, hpRole = "ready",
  lines = { { label = "KINETIC", value = "20%", role = "base" } },
  venting = "VENT READY", auto = "AUTO ON",
}
local ws = cv.build(withShield)
T.ok(ws:find("SHIELD", 1, true) ~= nil, "shield header")
T.ok(ws:find("KINETIC", 1, true) ~= nil, "resist line shown")
T.ok(ws:find("VENT READY", 1, true) ~= nil, "venting status shown")
T.ok(ws:find("AUTO ON", 1, true) ~= nil, "auto status shown")
