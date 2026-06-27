local flight = require("core.flight")

-- toG
T.ok(math.abs(flight.toG(9.80665) - 1) < 1e-9, "1g")
T.ok(math.abs(flight.toG(19.6133) - 2) < 1e-4, "2g")

-- brakeDistance: v=100 m/s, brake=200000 N, mass=50000 kg -> a=4 m/s^2 -> d=1250 m
T.ok(math.abs(flight.brakeDistance(100, 200000, 50000) - 1250) < 1e-6, "brake distance")
T.eq(flight.brakeDistance(100, 0, 50000), 0, "no brake force -> 0")
T.eq(flight.brakeDistance(100, 200000, 0), 0, "no mass -> 0")
T.eq(flight.brakeDistance(0, 200000, 50000), 0, "zero speed -> 0 distance")

-- ratio clamps to 0..1
T.ok(math.abs(flight.ratio(40, 80) - 0.5) < 1e-9, "ratio half")
T.eq(flight.ratio(100, 80), 1, "ratio clamps high")
T.eq(flight.ratio(-5, 80), 0, "ratio clamps low")
T.eq(flight.ratio(5, 0), 0, "ratio max 0 -> 0")
