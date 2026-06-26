-- Wires DU slots -> du adapters -> core logic -> render -> setScreen.
-- The only DU-coupled module besides du/. env carries the DU globals.
local format     = require("core.format")
local theme      = require("core.theme")
local channel    = require("core.channel")
local ballistics = require("core.ballistics")
local weaponsLib = require("core.weapons")
local dpsmod     = require("core.dps")
local threat     = require("core.threat")
local tracking   = require("core.tracking")
local duWeapon   = require("du.weapon")
local duRadar    = require("du.radar")
local duConstruct= require("du.construct")
local arLayer    = require("render.ar_layer")
local gunnerView = require("render.gunner_view")

local M = {}

function M.start(env)
  local sys = env.system
  local W = duWeapon.new(env.weapon)
  local R = duRadar.new(env.radar)
  local C = duConstruct.new(env.construct)
  local ch = channel.new(env.db, env.codec)
  ch.seed()
  local dps = dpsmod.new({})
  local track = tracking.new()
  local app = { dps = dps, tracking = track, channel = ch }

  local function avgHit(readings)
    if #readings == 0 then return 0 end
    local sum = 0
    for _, r in ipairs(readings) do sum = sum + (r.hitProbability or 0) end
    return math.floor(sum / #readings * 100 + 0.5)
  end

  function app.render()
    local sw, sh = sys.getScreenWidth(), sys.getScreenHeight()
    local readings = W.readings()
    local spec = W.firstSpec()

    -- weapons
    local wlist = {}
    for i, raw in ipairs(readings) do
      local d = weaponsLib.describe(raw)
      d.class = raw.class
      wlist[i] = d
    end

    -- target panel
    local target = nil
    local tid = R.targetId()
    if tid and tid ~= 0 then
      local info = R.info(tid)
      local optimal = spec and spec.optimalDistance or 0
      local spread = spec and ballistics.spread(spec.maxDistance, spec.optimalDistance) or 0
      local trackDeg = spec and spec.optimalTracking or 0
      local hitPct = avgHit(readings)
      target = {
        name = (info.name or ""):sub(1, 16),
        id3 = string.format("%03d", tid % 1000),
        coreSize = info.coreSize or "?",
        identified = info.identified,
        dist = format.distance(info.distance),
        distRole = ballistics.rangeBand(info.distance, optimal, spread),
        optimal = format.distance(optimal),
        angular = string.format("%d", math.floor(info.angular + 0.5)),
        angularRole = ballistics.angularBand(info.angular, trackDeg),
        hitPct = hitPct,
        hitRole = ballistics.hitBand(hitPct),
        speed = info.identified and format.speed(info.speed) or "?",
        maxSpeed = format.speed(ballistics.maxTargetSpeed(info.mass or 0)),
        closing = "-",
      }
    end

    -- AR markers
    local markers = {}
    local t = sys.getUtcTime()
    for _, id in ipairs(R.contacts()) do
      local info = R.info(id)
      if info.worldPos then
        track.update(id, { x = info.worldPos[1], y = info.worldPos[2], z = info.worldPos[3] }, t)
      end
      local predicted = track.predict(id, t)
      if predicted then
        local scr = C.toScreen(predicted, sw, sh)
        if scr then
          local cls = threat.classify({
            threatRate = info.threatRate, transponder = info.transponder,
            abandoned = info.abandoned, identified = info.identified,
          })
          markers[#markers + 1] = {
            x = scr.x, y = scr.y, role = cls.role,
            label = string.format("%03d", id % 1000),
            sub = format.distance(info.distance),
          }
        end
      end
    end

    local stats = {
      shotsFired = dps.shotsFired,
      shotsHit = dps.shotsHit,
      accuracy = string.format("%d%%", math.floor(dps.accuracy() * 100 + 0.5)),
      peakDps = format.compact(dps.peakDps),
      damage = format.compact(dps.damageDealt),
    }

    local html = gunnerView.build({
      screenW = sw, screenH = sh, css = theme.css(),
      weapons = wlist, target = target, stats = stats,
      graphSvg = "", markersSvg = arLayer.build(markers),
    })
    sys.setScreen(html)
    return html
  end

  function app.onUpdate() app.render() end
  function app.onWeaponHit(id, dmg) dps.recordHit(id, dmg) end
  function app.onWeaponMiss(id) dps.recordMiss(id) end
  function app.onDamage(amount) dps.recordReceived(amount) end
  function app.onTick() dps.tick() end

  return app
end

return M
