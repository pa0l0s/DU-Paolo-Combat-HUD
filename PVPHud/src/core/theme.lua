-- Retrosyncwave (classic synthwave) theme: palette + CSS/glow helpers.
-- Pure data + string builders; no DU globals.
local M = {}

M.palette = {
  base    = "#05d9e8", -- neon cyan: primary readouts
  threat  = "#ff2a6d", -- hot magenta: enemies / damage-in
  ready   = "#39ff14", -- neon green: friendly / good
  caution = "#f9f002", -- electric yellow: warnings
  warn    = "#ff6c11", -- neon orange: mid severity
  panel   = "#0d0221", -- deep indigo: panel background
  dim     = "#7700ff", -- violet: dead cores / faint grid
}

-- Semantic role -> hex; unknown role falls back to base.
function M.color(role)
  return M.palette[role] or M.palette.base
end

-- Neon glow as a CSS/SVG text-shadow string for a hex.
function M.glow(hex, radius)
  radius = radius or 6
  return string.format("0 0 %dpx %s, 0 0 %dpx %s", radius, hex, radius * 2, hex)
end

-- Shared <style> block consumed by render/.
function M.css()
  local p = M.palette
  local function rule(cls, hex)
    return string.format(".%s{color:%s;text-shadow:%s;}", cls, hex, M.glow(hex))
  end
  return "<style>"
    .. ".ui{font-family:monospace;font-weight:bold;white-space:pre;}"
    .. rule("base", p.base)
    .. rule("threat", p.threat)
    .. rule("ready", p.ready)
    .. rule("caution", p.caution)
    .. rule("warn", p.warn)
    .. "</style>"
end

return M
