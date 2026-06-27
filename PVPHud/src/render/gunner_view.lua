-- Pure HUD composition: view state -> full HTML string. No DU globals.
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
  -- Panels start below the game's own top-left/top-right HUD widgets.
  local top = 120

  -- Weapons panel (top-left)
  local wn = #state.weapons
  p[#p + 1] = widgets.panel(20, top, 360, 36 + wn * 26)
  p[#p + 1] = widgets.text(32, top + 24, "WEAPONS", "base", 18)
  for i, wp in ipairs(state.weapons) do
    local y = top + 24 + i * 26
    p[#p + 1] = widgets.text(32, y, (wp.class or "?") .. " " .. wp.label, wp.role, 15)
    p[#p + 1] = widgets.bar(190, y - 12, 170, 14, wp.barPct, wp.role)
  end

  -- Telemetry panel (right side, mid-screen: top-right is used by game windows)
  local sx = w - 320
  local ty = h / 2 - 80
  p[#p + 1] = widgets.panel(sx, ty, 300, 160)
  p[#p + 1] = widgets.text(sx + 12, ty + 24, "TELEMETRY", "base", 18)
  local st = state.stats
  local lines = {
    "FIRED   " .. st.shotsFired,
    "HIT     " .. st.shotsHit,
    "ACC     " .. st.accuracy,
    "PEAK    " .. st.peakDps,
    "DAMAGE  " .. st.damage,
  }
  for i, ln in ipairs(lines) do
    p[#p + 1] = widgets.text(sx + 12, ty + 24 + i * 22, ln, "base", 15)
  end
  if state.graphSvg and state.graphSvg ~= "" then p[#p + 1] = state.graphSvg end

  -- Target panel (center-top)
  local t = state.target
  if t then
    local tx, ty = w / 2 - 180, h / 2 - 210
    p[#p + 1] = widgets.panel(tx, ty, 360, 180)
    p[#p + 1] = widgets.text(tx + 90, ty + 24,
      "[" .. t.coreSize .. "] " .. t.id3 .. " " .. t.name, "base", 16)
    if not t.identified then
      p[#p + 1] = widgets.text(tx + 90, ty + 46, "UNIDENTIFIED", "threat", 14)
    end
    local rows = {
      { "DIST", t.dist, t.distRole },
      { "OPTIMAL", t.optimal, "base" },
      { "ANG", t.angular .. " deg/s", t.angularRole },
      { "HIT", t.hitPct .. "%", t.hitRole },
      { "SPEED", t.speed, "base" },
      { "MAXSPD", t.maxSpeed, "base" },
      { "CLOSING", t.closing, "base" },
    }
    for i, r in ipairs(rows) do
      local y = ty + 66 + (i - 1) * 15
      p[#p + 1] = widgets.text(tx + 14, y, r[1], "base", 13)
      p[#p + 1] = widgets.text(tx + 130, y, tostring(r[2]), r[3], 13)
    end
  end

  if state.markersSvg and state.markersSvg ~= "" then p[#p + 1] = state.markersSvg end
  p[#p + 1] = "</svg>"
  return table.concat(p)
end

return M
