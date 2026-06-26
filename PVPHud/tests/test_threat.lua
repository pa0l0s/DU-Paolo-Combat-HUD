local threat = require("core.threat")

local dead = threat.classify({ abandoned = true, friend = true, identified = true })
T.eq(dead.kind, "dead", "abandoned overrides friend")
T.eq(dead.role, "dim", "dead uses dim role")

local fr = threat.classify({ friend = true })
T.eq(fr.kind, "friend", "friend by friendlist")
T.eq(fr.role, "ready", "friend uses ready role")

local tr = threat.classify({ transponder = true })
T.eq(tr.kind, "friend", "transponder match => friend")

local en = threat.classify({ threatRate = 4 })
T.eq(en.kind, "enemy", "default is enemy")
T.eq(en.role, "threat", "enemy uses threat role")
T.eq(en.identified, false, "identified defaults false")

T.eq(threat.markerRole("friend"), "ready", "markerRole friend")
T.eq(threat.markerRole("dead"), "dim", "markerRole dead")
T.eq(threat.markerRole("enemy"), "threat", "markerRole enemy")
