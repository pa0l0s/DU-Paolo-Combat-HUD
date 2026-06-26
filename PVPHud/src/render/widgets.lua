-- Pure SVG/HTML primitives for the HUD, themed via core.theme. No DU globals.
local theme = require("core.theme")
local M = {}

-- XML-escape text content.
function M.escape(s)
  s = tostring(s)
  s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
  return s
end

-- Translucent neon glass panel.
function M.panel(x, y, w, h)
  return string.format(
    '<rect x="%d" y="%d" width="%d" height="%d" fill="%s" fill-opacity="0.55" stroke="%s" stroke-opacity="0.6"/>',
    x, y, w, h, theme.color("panel"), theme.color("base"))
end

-- Neon SVG text (bright fill; glow is carried by the bright palette).
function M.text(x, y, str, role, size)
  return string.format(
    '<text x="%d" y="%d" font-family="monospace" font-size="%d" fill="%s">%s</text>',
    x, y, size or 16, theme.color(role or "base"), M.escape(str))
end

-- Horizontal progress bar: faint track + neon fill.
function M.bar(x, y, w, h, pct, role)
  pct = math.max(0, math.min(1, pct or 0))
  local hex = theme.color(role or "ready")
  return string.format(
    '<rect x="%d" y="%d" width="%d" height="%d" fill="%s" fill-opacity="0.15"/>'
    .. '<rect x="%d" y="%d" width="%d" height="%d" fill="%s" fill-opacity="0.8"/>',
    x, y, w, h, hex, x, y, math.floor(w * pct), h, hex)
end

-- Polyline graph from y-values in 0..1 across a box.
function M.graph(x, y, w, h, points, role)
  if #points < 2 then return "" end
  local hex = theme.color(role or "base")
  local coords = {}
  for i, p in ipairs(points) do
    local px = x + (i - 1) / (#points - 1) * w
    local py = y + (1 - math.max(0, math.min(1, p))) * h
    coords[#coords + 1] = string.format("%.1f,%.1f", px, py)
  end
  return string.format(
    '<polyline points="%s" fill="none" stroke="%s" stroke-width="1.5"/>',
    table.concat(coords, " "), hex)
end

return M
