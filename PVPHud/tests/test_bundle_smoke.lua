local stubs = require("stubs")
local boot = require("bootstrap_smoke")

local sys = stubs.newSystem()
local db = stubs.newDatabank()
local codec = {
  encode = function(t) return next(t) and "json:ne" or "json:empty" end,
  decode = function(s) return s == "json:ne" and { 1 } or {} end,
}

local html = boot.start({ system = sys, build = 7, db = db, codec = codec })

T.ok(type(html) == "string", "start returns html string")
T.ok(html == sys._last.screen, "setScreen received the html")
T.ok(html:find("BUILD 7", 1, true) ~= nil, "banner shows build number")
T.ok(html:find("<style>", 1, true) ~= nil, "banner includes theme css")
T.ok(db.hasKey("pilotTarget"), "start seeds the channel")
