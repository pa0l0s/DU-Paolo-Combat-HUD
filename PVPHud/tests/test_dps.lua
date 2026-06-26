local dps = require("core.dps")

local d = dps.new({ buckets = 5, window = 2 })
T.eq(#d.series("caused"), 5, "buffer initialized to N buckets")
T.eq(d.accuracy(), 0, "accuracy 0 before any shots")

d.recordHit(42, 100)
d.recordHit(42, 50)
d.recordMiss(42)
T.eq(d.shotsFired, 3, "fired counts hits + misses")
T.eq(d.shotsHit, 2, "hits counted")
T.eq(d.damageDealt, 150, "total damage")
T.eq(d.damageById[42], 150, "per-target damage")
T.ok(math.abs(d.accuracy() - 2/3) < 1e-9, "accuracy = hits/fired")

-- current caused bucket holds 150 before any tick
local caused = d.series("caused")
T.eq(caused[#caused], 150, "damage lands in latest bucket")

d.recordReceived(80)
local rec = d.series("received")
T.eq(rec[#rec], 80, "received lands in latest bucket")

-- tick rolls: latest bucket becomes 0, length preserved, peak updated
d.tick()
T.eq(#d.series("caused"), 5, "length preserved after tick")
T.eq(d.series("caused")[5], 0, "new latest bucket is empty")
T.ok(d.peakDps > 0, "peak dps updated from window")
