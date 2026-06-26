local resist = require("core.resist")

-- allocate distributes the pool by stress proportion
local a = resist.allocate({ 0.5, 0.25, 0.25, 0 }, 100)
T.ok(math.abs(a[1] - 50) < 1e-9, "antimatter gets half")
T.ok(math.abs(a[2] - 25) < 1e-9, "em gets quarter")
T.ok(math.abs(a[3] - 25) < 1e-9, "kinetic gets quarter")
T.ok(math.abs(a[4] - 0) < 1e-9, "thermic gets none")

-- missing components treated as 0
local b = resist.allocate({ 1 }, 80)
T.ok(math.abs(b[1] - 80) < 1e-9, "single type takes whole pool")
T.ok(math.abs(b[4] - 0) < 1e-9, "absent component -> 0")

-- shouldUpdate
T.eq(resist.shouldUpdate({ 50, 0, 0, 0 }, { 40, 0, 0, 0 }, 1), true, "big diff -> update")
T.eq(resist.shouldUpdate({ 50, 0, 0, 0 }, { 50.5, 0, 0, 0 }, 1), false, "tiny diff -> skip")

-- isZero
T.eq(resist.isZero({ 0, 0, 0, 0 }), true, "all zero")
T.eq(resist.isZero({ 0, 0, 0.0001, 0 }), false, "non-zero detected")
