local gv = require("render.gunner_view")

local base = {
  screenW = 1920, screenH = 1080, css = "<style>X</style>",
  weapons = { { label = "FIRING", role = "ready", barPct = 0.8, class = "S" } },
  stats = { shotsFired = 3, shotsHit = 2, accuracy = "67%", peakDps = "1.2k", damage = "5.0k" },
  graphSvg = "", markersSvg = "",
}

local noTarget = gv.build(base)
T.ok(noTarget:find("<style>X</style>", 1, true) ~= nil, "includes css")
T.ok(noTarget:find("<svg", 1, true) ~= nil, "opens an svg overlay")
T.ok(noTarget:find("</svg>", 1, true) ~= nil, "closes the svg overlay")
T.ok(noTarget:find("WEAPONS", 1, true) ~= nil, "weapons header")
T.ok(noTarget:find("TELEMETRY", 1, true) ~= nil, "telemetry header")
T.ok(noTarget:find("FIRING", 1, true) ~= nil, "weapon label shown")

local withTarget = {}
for k, v in pairs(base) do withTarget[k] = v end
withTarget.target = {
  name = "Enemy Ship", id3 = "042", coreSize = "M", identified = false,
  dist = "1.2km", distRole = "caution", optimal = "2.0km",
  angular = "15", angularRole = "ready", hitPct = 80, hitRole = "ready",
  speed = "?", maxSpeed = "30,000 km/h", closing = "-",
}
local wt = gv.build(withTarget)
T.ok(wt:find("Enemy Ship", 1, true) ~= nil, "target name shown")
T.ok(wt:find("042", 1, true) ~= nil, "target id shown")
T.ok(wt:find("UNIDENTIFIED", 1, true) ~= nil, "unidentified flagged")
T.ok(wt:find("DIST", 1, true) ~= nil, "distance row present")
