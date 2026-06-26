local b = require("core.ballistics")

-- rangeBand: optimal=1000, spread=500
T.eq(b.rangeBand(900, 1000, 500), "ready", "in optimal")
T.eq(b.rangeBand(1000, 1000, 500), "ready", "at optimal boundary")
T.eq(b.rangeBand(1400, 1000, 500), "caution", "within spread")
T.eq(b.rangeBand(1600, 1000, 500), "threat", "beyond spread")

T.eq(b.spread(3000, 1000), 1000, "spread is half the optimal->max gap")

-- angularBand: tracking=20 deg/s
T.eq(b.angularBand(15, 20), "ready", "tracking ok")
T.eq(b.angularBand(35, 20), "caution", "within 2x tracking")
T.eq(b.angularBand(50, 20), "threat", "exceeds 2x tracking")
T.eq(b.angularBand(10, 0), "threat", "no tracking -> threat")

T.eq(b.hitBand(80), "ready", "high hit%")
T.eq(b.hitBand(50), "caution", "mid hit%")
T.eq(b.hitBand(10), "threat", "low hit%")

-- maxTargetSpeed: clamps to 50000 km/h at/below 10000 kg, to 20000 km/h when very heavy
T.ok(math.abs(b.maxTargetSpeed(10000) - 50000/3.6) < 1e-6, "light cap = 50000 km/h")
T.ok(math.abs(b.maxTargetSpeed(1e12) - 20000/3.6) < 1e-3, "very heavy cap = 20000 km/h")
T.ok(b.maxTargetSpeed(500000) < b.maxTargetSpeed(50000), "heavier is slower")
