-- Wires DU slots -> du adapters -> core logic -> render -> setScreen for the
-- Remote Controller HUD. The only DU-coupled module besides du/.
local format    = require("core.format")
local theme     = require("core.theme")
local channel   = require("core.channel")
local resist    = require("core.resist")
local ballistics= require("core.ballistics")
local flightCalc= require("core.flight")
local fuelCalc  = require("core.fuel")
local duShield  = require("du.shield")
local duFlight  = require("du.flight")
local duFuel    = require("du.fuel")
local duConstruct = require("du.construct")
local controllerView = require("render.controller_view")

local M = {}

local RES_LABELS = { "ANTIMATTER", "ELECTROMAG", "KINETIC", "THERMIC" }

function M.start(env)
  local sys = env.system
  local S = duShield.new(env.shield)
  local F = duFlight.new(env.construct, env.unit)
  -- env.json is a JSON module (e.g. dkjson); du.fuel wants the decode function.
  local FU = duFuel.new(env.fuel, env.json and env.json.decode) -- fuel container readings
  local C = duConstruct.new(env.library) -- getPointOnScreen projection
  local ch = channel.new(env.db, env.codec)
  ch.seed()
  local app = {
    autoResist = true, shieldAdapter = S, _brake = 0, _damping = 0, _warn = false,
    lowFuel = false,
    fuelLowLevel = env.fuelLowLevel or 0.2, -- fraction (0..1)
    fuelLowTime = env.fuelLowTime or 120,   -- seconds
  }

  -- Fuel types in display order; only present types (tanks > 0) are shown.
  local FUEL_TYPES = {
    { label = "ATMO", read = FU.atmo },
    { label = "SPACE", read = FU.space },
    { label = "ROCKET", read = FU.rocket },
  }

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

    -- Fuel: one row per present type (level bar + estimated burn time), and a
    -- low-fuel flag that drives the on-screen warning + audible alert.
    local fuelRows = {}
    local anyLow = false
    for _, ft in ipairs(FUEL_TYPES) do
      local agg = fuelCalc.aggregate(ft.read())
      if agg.present then
        local low = fuelCalc.isLow(agg, app.fuelLowLevel, app.fuelLowTime)
        anyLow = anyLow or low
        fuelRows[#fuelRows + 1] = {
          label = ft.label,
          level = agg.level,
          pct = string.format("%d%%", math.floor(agg.level * 100 + 0.5)),
          time = format.duration(agg.timeLeft),
          role = low and "threat" or "ready",
        }
      end
    end
    app.lowFuel = anyLow

    local html = controllerView.build({
      screenW = sw, screenH = sh, css = theme.css(),
      flight = flight, shield = shield, markersSvg = "",
      moveMarker = moveMarker, warn = app._warn,
      fuel = fuelRows, lowFuel = anyLow,
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
