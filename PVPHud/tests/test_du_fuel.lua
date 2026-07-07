local duFuel = require("du.fuel")

-- Minimal JSON decoder stub: understands the two fields we read.
local function decode(s)
  local t = {}
  local pct = s:match('"percentage"%s*:%s*([%d%.]+)')
  local tl = s:match('"timeLeft"%s*:%s*"?([%d%.]+)"?')
  if pct then t.percentage = tonumber(pct) end
  if tl then t.timeLeft = tonumber(tl) end
  return t
end

local function tank(pct, tl)
  return { getWidgetData = function()
    return string.format('{"percentage":%d,"timeLeft":"%d"}', pct, tl)
  end }
end

-- nil groups / nil decoder tolerated
local none = duFuel.new(nil, nil)
T.eq(#none.atmo(), 0, "nil groups -> empty")
T.eq(#duFuel.new({ atmo = { tank(50, 100) } }, nil).atmo(), 0, "no decoder -> empty")

local F = duFuel.new({
  space = { tank(80, 600), tank(40, 300) },
  rocket = { tank(10, 45) },
}, decode)

local sp = F.space()
T.eq(#sp, 2, "reads both space tanks")
T.ok(math.abs(sp[1].level - 0.8) < 1e-9, "percentage -> level fraction")
T.eq(sp[1].timeLeft, 600, "timeLeft parsed as seconds")
T.eq(#F.rocket(), 1, "reads rocket tank")
T.eq(#F.atmo(), 0, "no atmo tanks -> empty")

-- malformed / throwing element degrades to skip, not crash
local bad = duFuel.new({ atmo = { { getWidgetData = function() error("boom") end }, tank(25, 10) } }, decode)
T.eq(#bad.atmo(), 1, "throwing tank skipped, good one kept")
