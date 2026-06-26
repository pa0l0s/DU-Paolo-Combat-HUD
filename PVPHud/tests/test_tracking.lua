local tracking = require("core.tracking")

local tk = tracking.new()
T.eq(tk.predict(7, 0), nil, "unknown id predicts nil")

-- single observation: no velocity yet -> returns the observed position
tk.update(7, { x = 0, y = 0, z = 0 }, 0)
local p0 = tk.predict(7, 5)
T.ok(p0 ~= nil and p0.x == 0 and p0.y == 0 and p0.z == 0, "no velocity -> static position")

-- second observation establishes velocity (10 m/s on x)
tk.update(7, { x = 10, y = 0, z = 0 }, 1)
local p1 = tk.predict(7, 2)
T.ok(math.abs(p1.x - 20) < 1e-9, "extrapolates one second of velocity")
T.ok(math.abs(p1.y) < 1e-9 and math.abs(p1.z) < 1e-9, "no drift off-axis")

tk.forget(7)
T.eq(tk.predict(7, 3), nil, "forgotten id predicts nil")

-- dead-core memory
tk.markDead(999, { x = 1, y = 2, z = 3 })
local dc = tk.deadCores()
T.ok(dc[999] ~= nil and dc[999].y == 2, "dead core remembered")
tk.clearDead()
T.eq(next(tk.deadCores()), nil, "dead cores cleared")
