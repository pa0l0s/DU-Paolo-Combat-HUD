local W = require("render.widgets")
local theme = require("core.theme")

T.ok(W.panel(10, 20, 100, 50):find('<rect', 1, true) ~= nil, "panel is a rect")
T.ok(W.panel(10, 20, 100, 50):find(theme.color("panel"), 1, true) ~= nil, "panel uses panel color")

local t = W.text(5, 9, "HP <50>", "threat", 14)
T.ok(t:find(theme.color("threat"), 1, true) ~= nil, "text uses role color")
T.ok(t:find("HP &lt;50&gt;", 1, true) ~= nil, "text escapes angle brackets")

-- bar clamps pct and floors fill width
local b = W.bar(0, 0, 200, 10, 0.5, "ready")
T.ok(b:find('width="100"', 1, true) ~= nil, "bar fill is floor(width*pct)")
local bover = W.bar(0, 0, 200, 10, 2, "ready")
T.ok(bover:find('width="200"', 1, true) ~= nil, "bar pct clamped to 1")

-- graph emits a polyline with one coord per point
local g = W.graph(0, 0, 100, 50, { 0, 0.5, 1 }, "base")
T.ok(g:find("<polyline", 1, true) ~= nil, "graph is a polyline")
local _, commas = g:gsub(" %d", "")
T.ok(g:find("points=", 1, true) ~= nil, "graph has points attr")
T.eq(W.graph(0, 0, 100, 50, { 0.5 }, "base"), "", "graph needs >= 2 points")

T.eq(W.escape("a&b<c>"), "a&amp;b&lt;c&gt;", "escape ampersand and brackets")
