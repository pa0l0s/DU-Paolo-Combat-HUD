local ar = require("render.ar_layer")
local theme = require("core.theme")

T.eq(ar.build({}), "", "no markers -> empty")

local s = ar.build({ { x = 100, y = 200, label = "042", sub = "1.2km", role = "threat" } })
T.ok(s:find("<rect", 1, true) ~= nil, "marker has a box")
T.ok(s:find(theme.color("threat"), 1, true) ~= nil, "marker uses role color")
T.ok(s:find(">042<", 1, true) ~= nil, "marker shows label")
T.ok(s:find(">1.2km<", 1, true) ~= nil, "marker shows sub")

local none = ar.build({ { x = 10, y = 10, role = "ready" } })
T.ok(none:find("<rect", 1, true) ~= nil, "marker without text still draws box")
