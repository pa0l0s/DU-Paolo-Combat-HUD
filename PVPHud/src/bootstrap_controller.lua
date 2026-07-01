-- Wires DU slots -> du adapters -> core logic -> render -> setScreen for the
-- Remote Controller HUD. The only DU-coupled module besides du/.
local format    = require("core.format")
local theme     = require("core.theme")
local channel   = require("core.channel")
local resist    = require("core.resist")
local ballistics= require("core.ballistics")
local flightCalc= require("core.flight")
local duShield  = require("du.shield")
local duFlight  = require("du.flight")
local duConstruct = require("du.construct")
local controllerView = require("render.controller_view")

local M = {}

local RES_LABELS = { "ANTIMATTER", "ELECTROMAG", "KINETIC", "THERMIC" }

function M.start(env)
  local sys = env.system
  local S = duShield.new(env.shield)
  local F = duFlight.new(env.construct, env.unit)
  local C = duConstruct.new(env.library) -- getPointOnScreen projection
  local ch = channel.new(env.db, env.codec)
  ch.seed()
  local app = { autoResist = true, shieldAdapter = S, _brake = 0, _damping = 0, _warn = false }

  function app.render()
    local sw, sh = sys.getScreenWidth(), sys.getScreenHeight()

    local mass = F.mass()
    local speedMps = F.speed()
    local throttle = F.throttlePct()
    local brakeOn = app._brake == 1
    local smooth = app._damping == 1
    local flight = {
      speed = format.speed(speedMps),
      mass = format.compact(mass / 1000) .. " t",
      maxSpeed = format.speed(ballistics.maxTargetSpeed(mass)),
      throttleStr = string.format("%d%%", math.floor(throttle + 0.5)),
      throttleBar = flightCalc.ratio(throttle, 100),
      throttleRole = (throttle < 0) and "warn" or "ready",
      engineRatio = F.engineRatio(),
      outputG = string.format("%.1f g", F.accelG()),
      brakeState = brakeOn and "BRAKE ON" or "BRAKE OFF",
      brakeRole = brakeOn and "caution" or "base",
      brakeDist = format.distance(flightCalc.brakeDistance(speedMps, F.maxBrake(), mass)),
      rotMode = smooth and "SMOOTH" or "STABLE",
      rotRole = smooth and "caution" or "base",
    }

    local shield = nil
    if S.present() then
      local res = S.resistances()
      local lines = {}
      for i = 1, 4 do
        lines[i] = {
          label = RES_LABELS[i],
          value = string.format("%d%%", math.floor((res[i] or 0) * 100 + 0.5)),
          role = "base",
        }
      end
      local venting
      if S.isVenting() then venting = "VENTING"
      elseif S.ventCooldown() > 0 then venting = "COOLDOWN " .. math.ceil(S.ventCooldown()) .. "s"
      else venting = "VENT READY" end
      shield = {
        hpPct = S.hpPct(),
        hpRole = (S.hpPct() > 0.33) and "ready" or "threat",
        lines = lines,
        venting = venting,
        auto = app.autoResist and "AUTO ON" or "AUTO OFF",
      }
    end

    -- Move-direction (prograde) marker: project a point along the velocity vector.
    local moveMarker = nil
    local cn = env.construct
    if cn and cn.getWorldPosition and cn.getWorldVelocity then
      local function arr(t) return { t[1] or t.x or 0, t[2] or t.y or 0, t[3] or t.z or 0 } end
      local vel = arr(cn.getWorldVelocity())
      local vl = math.sqrt(vel[1] ^ 2 + vel[2] ^ 2 + vel[3] ^ 2)
      if vl > 1 then
        local pos = arr(cn.getWorldPosition())
        local D = 1000
        local scr = C.toScreen(
          { x = pos[1] + vel[1] / vl * D, y = pos[2] + vel[2] / vl * D, z = pos[3] + vel[3] / vl * D },
          sw, sh)
        if scr then moveMarker = { x = scr.x, y = scr.y } end
      end
    end

    local html = controllerView.build({
      screenW = sw, screenH = sh, css = theme.css(),
      flight = flight, shield = shield, markersSvg = "",
      moveMarker = moveMarker, warn = app._warn,
    })
    sys.setScreen(html)
    return html
  end

  -- Dynamic auto-resist: shift the resistance pool toward the highest incoming
  -- damage type, when enabled, off cooldown, and there is meaningful stress.
  function app.onFlush()
    if not app.autoResist or not S.present() then return end
    if S.cooldown() ~= 0 then return end
    local stress = S.stressRatio()
    if resist.isZero(stress) then return end
    local target = resist.allocate(stress, S.pool())
    if resist.shouldUpdate(target, S.resistances(), 0.01) then
      S.setResistances(target[1], target[2], target[3], target[4])
    end
  end

  -- brake/damping = the live brakeInput / dampingOff globals from the conf handlers.
  function app.onUpdate(brake, damping, warn)
    app._brake = brake or 0
    app._damping = damping or 0
    app._warn = warn and true or false
    app.render()
  end
  function app.toggleAuto() app.autoResist = not app.autoResist end
  function app.toggleVent()
    if not S.present() then return end
    if S.isVenting() then S.stopVenting() else S.startVenting() end
  end

  return app
end

return M
