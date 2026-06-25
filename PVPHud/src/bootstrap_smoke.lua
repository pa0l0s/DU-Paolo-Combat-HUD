-- Tiny entry that proves the bundle pipeline: core modules -> HUD screen.
local format  = require("core.format")
local theme   = require("core.theme")
local channel = require("core.channel")

local M = {}

-- env = { system, build, db (optional), codec (optional) }
function M.start(env)
  local ch = channel.new(env.db, env.codec)
  ch.seed()

  local html = theme.css()
    .. '<div class="ui base">'
    .. "PVPHUD SELF-TEST — BUILD " .. tostring(env.build) .. "\n"
    .. "range " .. format.distance(2500) .. "  speed " .. format.speed(100) .. "\n"
    .. "target " .. tostring(ch.getInt("pilotTarget"))
    .. "</div>"

  env.system.setScreen(html)
  return html
end

return M
