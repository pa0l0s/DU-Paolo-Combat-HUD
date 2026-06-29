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
local controllerView = require("render.controller_view")

local M = {}

local RES_LABELS = { "ANTIMATTER", "ELECTROMAG", "KINETIC", "THERMIC" }

function M.start(env)
  local sys = env.system
  local S = duShield.new(env.shield)
  local F = duFlight.new(env.construct, env.unit)
  local ch = channel.new(env.db, env.codec)
  ch.seed()
  local app = { autoResist = true, shieldAdapter = S, _brake = 0 }

  function app.render()
    local sw, sh = sys.getScreenWidth(), sys.getScreenHeight()

    local mass = F.mass()
    local speedMps = F.speed()
    local throttle = F.throttlePct()
    local brakeOn = app._brake == 1
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

    local html = controllerView.build({
      screenW = sw, screenH = sh, css = theme.css(),
      flight = flight, shield = shield, markersSvg = "",
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

  -- brake = the live brakeInput global (0/1), passed in from the conf handler.
  function app.onUpdate(brake) app._brake = brake or 0; app.render() end
  function app.toggleAuto() app.autoResist = not app.autoResist end
  function app.toggleVent()
    if not S.present() then return end
    if S.isVenting() then S.stopVenting() else S.startVenting() end
  end

  return app
end

return M
