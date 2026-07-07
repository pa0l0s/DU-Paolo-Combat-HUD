local fuel = require("core.fuel")

-- empty / nil -> not present
T.eq(fuel.aggregate(nil).present, false, "nil tanks not present")
T.eq(fuel.aggregate({}).present, false, "empty tanks not present")

-- aggregate: average level, worst-case (min) time, clamped
local agg = fuel.aggregate({
  { level = 0.8, timeLeft = 300 },
  { level = 0.4, timeLeft = 120 },
  { level = 1.5, timeLeft = nil }, -- clamps to 1
})
T.eq(agg.present, true, "present with tanks")
T.eq(agg.count, 3, "counts tanks")
T.ok(math.abs(agg.level - (0.8 + 0.4 + 1.0) / 3) < 1e-9, "average level, clamped")
T.eq(agg.timeLeft, 120, "min (worst-case) time left")

-- timeLeft nil when no tank reports a positive time
local noTime = fuel.aggregate({ { level = 0.5 }, { level = 0.5, timeLeft = 0 } })
T.eq(noTime.timeLeft, nil, "no known time -> nil")

-- isLow: by level
T.eq(fuel.isLow(fuel.aggregate({ { level = 0.1, timeLeft = 999 } }), 0.2, 60), true, "low by level")
T.eq(fuel.isLow(fuel.aggregate({ { level = 0.9, timeLeft = 999 } }), 0.2, 60), false, "not low")
-- isLow: by time even when level ok
T.eq(fuel.isLow(fuel.aggregate({ { level = 0.9, timeLeft = 30 } }), 0.2, 60), true, "low by time")
-- absent never low
T.eq(fuel.isLow(fuel.aggregate({}), 0.2, 60), false, "absent never low")
