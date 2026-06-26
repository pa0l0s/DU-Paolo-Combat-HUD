-- Pure AR marker layout: projected screen coords -> SVG elements. No DU globals.
local theme = require("core.theme")
local M = {}

function M.build(markers)
  local out = {}
  for _, m in ipairs(markers) do
    local hex = theme.color(m.role or "threat")
    out[#out + 1] = string.format(
      '<rect x="%.1f" y="%.1f" width="20" height="20" fill="none" stroke="%s" stroke-width="2"/>',
      m.x - 10, m.y - 10, hex)
    if m.label then
      out[#out + 1] = string.format(
        '<text x="%.1f" y="%.1f" font-family="monospace" font-size="13" fill="%s" text-anchor="middle">%s</text>',
        m.x, m.y - 14, hex, m.label)
    end
    if m.sub then
      out[#out + 1] = string.format(
        '<text x="%.1f" y="%.1f" font-family="monospace" font-size="13" fill="%s" text-anchor="middle">%s</text>',
        m.x, m.y + 26, hex, m.sub)
    end
  end
  return table.concat(out)
end

return M
