-- Pure controller HUD composition: view state -> HTML. No DU globals.
local widgets = require("render.widgets")
local M = {}

local function svgOpen(w, h)
  return string.format(
    '<svg style="position:absolute;top:0;left:0;width:100vw;height:100vh;'
    .. 'overflow:visible;pointer-events:none" viewBox="0 0 %d %d">', w, h)
end

function M.build(state)
  local w, h = state.screenW, state.screenH
  local p = { state.css or "", svgOpen(w, h) }

  -- Flight panel (bottom-center): speed, throttle set + engine warm-up bars,
  -- output g, and brake state + brake distance.
  local f = state.flight
  local fx, fy = w / 2 - 210, h - 250
  p[#p + 1] = widgets.panel(fx, fy, 420, 220)
  p[#p + 1] = widgets.text(fx + 14, fy + 26, "FLIGHT", "base", 18)
  p[#p + 1] = widgets.text(fx + 14, fy + 50, "SPEED   " .. f.speed, "base", 15)
  -- throttle SET
  p[#p + 1] = widgets.text(fx + 14, fy + 78, "THR " .. f.throttleStr, f.throttleRole or "base", 15)
  p[#p + 1] = widgets.bar(fx + 120, fy + 66, 286, 14, f.throttleBar, f.throttleRole or "ready")
  -- ENGINE output (warm-up ramp toward the throttle set)
  p[#p + 1] = widgets.text(fx + 14, fy + 104, "ENG", "base", 15)
  p[#p + 1] = widgets.bar(fx + 120, fy + 92, 286, 14, f.engineRatio, "caution")
  -- output acceleration in g
  p[#p + 1] = widgets.text(fx + 14, fy + 130, "OUTPUT  " .. f.outputG, "base", 15)
  -- brake state + always-on brake distance + getMaxBrake diagnostic
  p[#p + 1] = widgets.text(fx + 14, fy + 158, f.brakeState, f.brakeRole or "base", 16)
  p[#p + 1] = widgets.text(fx + 150, fy + 158, "DIST " .. f.brakeDist, "base", 15)
  p[#p + 1] = widgets.text(fx + 300, fy + 158, "MAXBRK " .. f.maxBrake, "warn", 13)
  -- mass / max speed
  p[#p + 1] = widgets.text(fx + 14, fy + 192, "MASS " .. f.mass, "base", 13)
  p[#p + 1] = widgets.text(fx + 220, fy + 192, "MAX " .. f.maxSpeed, "base", 13)

  -- Shield panel (left)
  local s = state.shield
  if s then
    local sx, sy = 20, h / 2 - 120
    p[#p + 1] = widgets.panel(sx, sy, 300, 200)
    p[#p + 1] = widgets.text(sx + 12, sy + 26, "SHIELD", "base", 18)
    p[#p + 1] = widgets.bar(sx + 12, sy + 38, 276, 16, s.hpPct, s.hpRole or "ready")
    for i, ln in ipairs(s.lines) do
      local y = sy + 80 + (i - 1) * 22
      p[#p + 1] = widgets.text(sx + 12, y, ln.label, "base", 14)
      p[#p + 1] = widgets.text(sx + 150, y, ln.value, ln.role or "base", 14)
    end
    p[#p + 1] = widgets.text(sx + 12, sy + 180, s.venting, "caution", 14)
    p[#p + 1] = widgets.text(sx + 170, sy + 180, s.auto, "ready", 14)
  end

  if state.markersSvg and state.markersSvg ~= "" then p[#p + 1] = state.markersSvg end
  p[#p + 1] = "</svg>"
  return table.concat(p)
end

return M
