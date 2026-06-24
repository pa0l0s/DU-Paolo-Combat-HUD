-- Base Inventory Monitor (Dual Universe) -- single source of truth.
-- Pure logic + DU bootstrap. Exposes global BIM so local tests can reach it.
BIM = BIM or {}
local M = BIM

-- Debug logging to the board console / game log (grep the log for "[BIM]").
-- Toggle off with the `debug` export.
-- NOTE: in DU, injected globals (system, unit, slot1..slot10) must be referenced
-- directly by name, not through the global table -- so we do that everywhere below.
local function dbg(msg)
  if M.debug == false then return end
  if system and system.print then
    system.print("[BIM] " .. tostring(msg))
  end
end

local function round1(n) return math.floor(n * 10 + 0.5) / 10 end

function M.formatVolume(liters)
  liters = liters or 0
  if liters < 1000 then return string.format("%d L", math.floor(liters + 0.5)) end
  if liters < 1000000 then return string.format("%s kL", round1(liters / 1000)) end
  if liters < 1000000000 then return string.format("%s ML", round1(liters / 1000000)) end
  return string.format("%s GL", round1(liters / 1000000000))
end

function M.formatMass(kg)
  return string.format("%.1f t", (kg or 0) / 1000)
end

function M.formatPct(pct)
  pct = pct or 0
  if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
  return string.format("%d%%", math.floor(pct + 0.5))
end

local MAX_SLOTS = 10  -- a Programming Board exposes slot1..slot10

-- Best-effort in-game name of a linked element handle (Element.getName()).
local function handleName(c, idx)
  local label = nil
  pcall(function() label = c.getName() end)
  if label == nil or label == "" then label = "Container " .. tostring(idx) end
  return label
end

-- Build a label from a container's actual contents.
-- content: array of {id, quantity} (from getContent()). getItem(id) -> item table.
-- Returns nil when there is nothing to name from (so callers can fall back to the
-- element's own name). Uniform tier is prefixed ("T1 ..."); up to maxShown item
-- names are listed by quantity, with "+N" for the remainder.
function M.itemLabel(content, getItem, maxShown)
  if not content or #content == 0 or not getItem then return nil end
  maxShown = maxShown or 2
  local qty, order = {}, {}
  for _, e in ipairs(content) do
    local id = e.id or e[1]
    local q = e.quantity or e[2] or 0
    if id and id ~= 0 then
      if not qty[id] then qty[id] = 0; order[#order + 1] = id end
      qty[id] = qty[id] + q
    end
  end
  if #order == 0 then return nil end
  local items = {}
  for _, id in ipairs(order) do
    local it = getItem(id)
    local name = it and (it.locDisplayName or it.displayName or it.name) or ("#" .. tostring(id))
    items[#items + 1] = { name = name, tier = it and it.tier, q = qty[id] }
  end
  table.sort(items, function(a, b) return a.q > b.q end)
  local utier = items[1].tier
  for _, it in ipairs(items) do if it.tier ~= utier then utier = nil; break end end
  local shown = {}
  for i = 1, math.min(maxShown, #items) do shown[#shown + 1] = items[i].name end
  local label = table.concat(shown, ", ")
  if #items > maxShown then label = label .. " +" .. (#items - maxShown) end
  if utier then label = "T" .. tostring(utier) .. " " .. label end
  return label
end

-- Read one linked container/hub handle into a row record.
-- opts: { getItem = function(id)->item, labelMode = "auto"|"items"|"name" }
local function readContainer(c, idx, opts)
  opts = opts or {}
  local mode = opts.labelMode or "auto"
  local label
  if mode ~= "name" then
    local content = nil
    pcall(function() content = c.getContent() end)
    label = M.itemLabel(content, opts.getItem)
  end
  if not label then label = handleName(c, idx) end  -- name mode / fallback

  local vol = c.getItemsVolume()
  local maxVol = c.getMaxVolume()
  local mass = c.getItemsMass()
  local pct = 0
  if maxVol and maxVol > 0 then pct = (vol / maxVol) * 100 end
  return { label = label, vol = vol or 0, maxVol = maxVol or 0,
           mass = mass or 0, pct = pct, ok = true }
end

-- Build rows from an array of container/hub handles (already filtered).
-- opts forwarded to readContainer. A failed read becomes ok=false.
function M.buildRows(containers, opts)
  local rows = {}
  for i = 1, #containers do
    local c = containers[i]
    if c ~= nil then
      local ok, row = pcall(readContainer, c, i, opts)
      if ok then
        rows[#rows + 1] = row
      else
        rows[#rows + 1] = { label = handleName(c, i), vol = 0, maxVol = 0,
                            mass = 0, pct = 0, ok = false }
      end
    end
  end
  return rows
end

-- Classify an array of linked slot handles into a screen + container list.
-- Each handle exposes getClass(); screens match "Screen", containers/hubs match "Container".
function M.classify(slots)
  local screen, containers = nil, {}
  for i = 1, #slots do
    local s = slots[i]
    if s ~= nil then
      local cls = nil
      pcall(function() cls = s.getClass() end)
      cls = cls or ""
      if (not screen) and cls:find("Screen", 1, true) then
        screen = s
      elseif cls:find("Container", 1, true) then
        containers[#containers + 1] = s
      end
    end
  end
  return { screen = screen, containers = containers }
end

function M.sortRows(rows, mode)
  if mode == "none" then return rows end
  local cmp
  if mode == "fill-asc" then
    cmp = function(a, b) return a.pct < b.pct end
  elseif mode == "name" then
    cmp = function(a, b) return tostring(a.label) < tostring(b.label) end
  else -- "fill-desc" default
    cmp = function(a, b) return a.pct > b.pct end
  end
  table.sort(rows, cmp)
  return rows
end

function M.aggregate(rows)
  local totalVol, totalMax, count = 0, 0, 0
  for _, r in ipairs(rows) do
    if r.ok then
      totalVol = totalVol + (r.vol or 0)
      totalMax = totalMax + (r.maxVol or 0)
      count = count + 1
    end
  end
  local pct = 0
  if totalMax > 0 then pct = math.floor((totalVol / totalMax) * 100 + 0.5) end
  return { totalVol = totalVol, totalMax = totalMax, pct = pct, count = count }
end

function M.classifyLevel(pct, warnPct, critPct)
  if pct >= critPct then return "crit"
  elseif pct >= warnPct then return "warn"
  else return "ok" end
end

local function esc(s)
  s = tostring(s or "")
  s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
  return s
end

-- Bar color per level.
local LEVEL_COLOR = { ok = "#00f3ff", warn = "#fffb00", crit = "#ff007f" }

local function renderRow(M, r, warnPct, critPct)
  if not r.ok then
    return string.format(
      '<div class="row offline"><div class="name">%s</div>'
      .. '<div class="bar"><div class="fill" style="width:0%%"></div></div>'
      .. '<div class="stat">OFFLINE</div></div>', esc(r.label))
  end
  local level = M.classifyLevel(r.pct, warnPct, critPct)
  local color = LEVEL_COLOR[level]
  local pctInt = math.floor(r.pct + 0.5)
  return string.format(
    '<div class="row %s"><div class="name">%s</div>'
    .. '<div class="bar"><div class="fill" style="width:%d%%;background:%s;box-shadow:0 0 10px %s,0 0 20px %s"></div></div>'
    .. '<div class="stat"><span class="vol">%s / %s</span>'
    .. '<span class="mass">%s</span><span class="pct">%s</span></div></div>',
    level, esc(r.label), pctInt, color, color, color,
    M.formatVolume(r.vol), M.formatVolume(r.maxVol), M.formatMass(r.mass), M.formatPct(r.pct))
end

local CSS = [[
<style>
*{margin:0;padding:0;box-sizing:border-box;font-family:'Consolas','Courier New',monospace;}
html,body{width:100%;height:100%;}
.bim{position:absolute;top:0;left:0;width:100%;height:100%;background:#0d0211;color:#e7d9f5;overflow:hidden;}
.bim .grid{position:absolute;inset:0;background-image:linear-gradient(#2a0a3a 1px,transparent 1px),linear-gradient(90deg,#2a0a3a 1px,transparent 1px);background-size:4vh 4vh;opacity:0.25;}
.bim .scanline{position:absolute;inset:0;background:repeating-linear-gradient(transparent 0,transparent 3px,rgba(0,0,0,0.25) 3px,rgba(0,0,0,0.25) 4px);pointer-events:none;opacity:0.5;}
.bim .wrap{position:relative;padding:3vh 4vw;height:100%;display:flex;flex-direction:column;}
.bim .title{font-size:5vh;font-weight:bold;letter-spacing:0.4vw;color:#00f3ff;text-shadow:0 0 8px #00f3ff,0 0 18px #ff007f;}
.bim .sub{font-size:2.2vh;color:#b10dc9;margin-top:0.5vh;text-shadow:0 0 6px #b10dc9;}
.bim .total{margin:2vh 0;}
.bim .total .bar{height:3vh;}
.bim .rows{flex:1;overflow:hidden;display:flex;flex-direction:column;gap:1.2vh;}
.bim .row{display:flex;align-items:center;gap:1.5vw;}
.bim .row .name{width:22vw;font-size:2.4vh;color:#00f3ff;text-shadow:0 0 6px #00f3ff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}
.bim .bar{flex:1;height:2.6vh;background:rgba(255,255,255,0.06);border:1px solid #3a1150;border-radius:1vh;overflow:hidden;}
.bim .fill{height:100%;border-radius:1vh;transition:width 0.4s;}
.bim .stat{width:24vw;display:flex;justify-content:flex-end;gap:1vw;font-size:2vh;}
.bim .stat .vol{color:#e7d9f5;} .bim .stat .mass{color:#b10dc9;} .bim .stat .pct{color:#fff;width:5vw;text-align:right;}
.bim .row.crit .fill{animation:pulse 1s infinite;}
.bim .row.crit .pct{color:#ff007f;text-shadow:0 0 8px #ff007f;}
@keyframes pulse{0%,100%{filter:brightness(1);}50%{filter:brightness(1.6);}}
.bim .panel{margin:auto;text-align:center;font-size:3vh;color:#ff007f;text-shadow:0 0 10px #ff007f;}
.bim .footer{font-size:1.8vh;color:#5a3a70;margin-top:1.5vh;}
</style>
]]

function M.renderHTML(model)
  local parts = {}
  parts[#parts+1] = '<div class="bim"><div class="grid"></div><div class="scanline"></div>'
  parts[#parts+1] = CSS
  parts[#parts+1] = '<div class="wrap">'
  parts[#parts+1] = string.format('<div class="title">%s</div>', esc(model.title))

  if model.error then
    parts[#parts+1] = string.format('<div class="panel">&#9888; %s</div>', esc(model.error))
    parts[#parts+1] = '</div></div>'
    return table.concat(parts)
  end

  parts[#parts+1] = string.format(
    '<div class="sub">%d CONTAINERS &bull; BASE FILL %s</div>',
    model.agg.count, M.formatPct(model.agg.pct))

  -- Base total bar (uses 'ok' coloring scaled by thresholds).
  local tlevel = M.classifyLevel(model.agg.pct, model.warnPct, model.critPct)
  local tcolor = LEVEL_COLOR[tlevel]
  parts[#parts+1] = string.format(
    '<div class="total"><div class="bar"><div class="fill" style="width:%d%%;background:%s;box-shadow:0 0 12px %s"></div></div></div>',
    math.floor(model.agg.pct + 0.5), tcolor, tcolor)

  if #model.rows == 0 then
    parts[#parts+1] = '<div class="panel">No containers linked</div>'
  else
    parts[#parts+1] = '<div class="rows">'
    for _, r in ipairs(model.rows) do
      parts[#parts+1] = renderRow(M, r, model.warnPct, model.critPct)
    end
    parts[#parts+1] = '</div>'
  end

  parts[#parts+1] = string.format('<div class="footer">SYNC #%d &nbsp;&bull;&nbsp; build %s</div>',
    model.tick or 0, esc(model.build or "dev"))
  parts[#parts+1] = '</div></div>'
  return table.concat(parts)
end

-- ===== Screen render-script path (setHTML is deprecated on DU screens) =====
-- Encode the model as a tab/newline string fed to the render script via setScriptInput.
-- Header line: title \t build \t aggPct \t count \t warnPct \t critPct \t tick
-- Row lines:   label \t pct \t volStr \t maxStr \t massStr
local function san(s) return (tostring(s or ""):gsub("[\t\n]", " ")) end

function M.buildScreenData(model)
  local lines = {}
  lines[1] = table.concat({
    san(model.title), san(model.build or "dev"), tostring(math.floor((model.agg.pct or 0) + 0.5)),
    tostring(model.agg.count or 0), tostring(model.warnPct or 75),
    tostring(model.critPct or 90), tostring(model.tick or 0),
  }, "\t")
  for _, r in ipairs(model.rows) do
    if r.ok then
      lines[#lines + 1] = table.concat({
        san(r.label), tostring(math.floor((r.pct or 0) + 0.5)),
        M.formatVolume(r.vol), M.formatVolume(r.maxVol), M.formatMass(r.mass),
      }, "\t")
    else
      lines[#lines + 1] = table.concat({ san(r.label), "0", "OFFLINE", "", "" }, "\t")
    end
  end
  return table.concat(lines, "\n")
end

-- The render script that runs ON the screen. Reads getInput() (the string above),
-- draws the synthwave UI with the screen render API. Kept as a string constant.
M.RENDER_SCRIPT = [==[
local rx, ry = getResolution()
local bg = createLayer()
local fg = createLayer()
local fTitle = loadFont('Play-Bold', math.floor(ry * 0.080))
local fRow   = loadFont('Play', math.floor(ry * 0.042))
local fStat  = loadFont('RobotoMono', math.floor(ry * 0.034))
local function col(l, r, g, b, a) setNextFillColor(l, r/255, g/255, b/255, a or 1) end

col(bg, 13, 2, 17, 1); addBox(bg, 0, 0, rx, ry)

local input = getInput() or ''
local hdr, rows = nil, {}
for line in (input .. '\n'):gmatch('(.-)\n') do
  if line ~= '' then
    local f = {}
    for fld in (line .. '\t'):gmatch('(.-)\t') do f[#f + 1] = fld end
    if not hdr then hdr = f else rows[#rows + 1] = f end
  end
end

local pad = rx * 0.04
if not hdr then
  col(fg, 255, 0, 127, 1); setNextTextAlign(fg, AlignH_Center, AlignV_Middle)
  addText(fg, fTitle, 'BASE INVENTORY -- no data', rx / 2, ry / 2)
else
  local title = hdr[1] or 'BASE INVENTORY'
  local build = hdr[2] or ''
  local aggPct = tonumber(hdr[3]) or 0
  local count = hdr[4] or '0'
  local warnPct = tonumber(hdr[5]) or 75
  local critPct = tonumber(hdr[6]) or 90
  local tick = hdr[7] or '0'

  local padX = rx * 0.045

  -- Title (subtle glow) + sub-line.
  setNextShadow(fg, ry * 0.007, 0, 243/255, 1, 0.55)
  col(fg, 0, 243, 255, 1); setNextTextAlign(fg, AlignH_Left, AlignV_Top)
  addText(fg, fTitle, title, padX, ry * 0.045)

  col(fg, 177, 13, 201, 1); setNextTextAlign(fg, AlignH_Right, AlignV_Top)
  addText(fg, fRow, count .. ' CONT  ' .. aggPct .. '%', rx - padX, ry * 0.06)

  -- Rows: full-width bars with the label + stats drawn OVER the bar.
  local top = ry * 0.22
  local bottom = ry * 0.95
  local n = #rows
  if n < 1 then n = 1 end
  local slotH = (bottom - top) / n
  local barH = slotH * 0.84
  if barH > ry * 0.085 then barH = ry * 0.085 end
  local barX, barW = padX, rx - 2 * padX
  local inset = barH * 0.4

  for i = 1, #rows do
    local r = rows[i]
    local label = r[1] or ''
    local pct = tonumber(r[2]) or 0
    local volS, maxS, massS = r[3] or '', r[4] or '', r[5] or ''
    local y = top + (i - 1) * slotH
    local cy = y + barH / 2
    local rad = barH * 0.22

    -- empty track
    col(fg, 255, 255, 255, 0.06)
    addBoxRounded(fg, barX, y, barW, barH, rad)

    -- translucent fill (acts as the text background)
    local cr, cg, cb = 0, 243, 255
    if pct >= critPct then cr, cg, cb = 255, 0, 127
    elseif pct >= warnPct then cr, cg, cb = 255, 251, 0 end
    local w = barW * math.min(pct, 100) / 100
    if w > rad * 2 then
      setNextFillColor(fg, cr/255, cg/255, cb/255, 0.5)
      addBoxRounded(fg, barX, y, w, barH, rad)
    end

    -- label over the bar (left), white with a dark outline for contrast
    setNextShadow(fg, ry * 0.004, 0, 0, 0, 0.95)
    col(fg, 255, 255, 255, 1); setNextTextAlign(fg, AlignH_Left, AlignV_Middle)
    addText(fg, fRow, label, barX + inset, cy)

    -- stats over the bar (right)
    setNextShadow(fg, ry * 0.004, 0, 0, 0, 0.95)
    col(fg, 255, 255, 255, 1); setNextTextAlign(fg, AlignH_Right, AlignV_Middle)
    addText(fg, fStat, pct .. '%   ' .. volS .. ' / ' .. maxS .. '   ' .. massS, barX + barW - inset, cy)
  end

  col(fg, 110, 70, 140, 1); setNextTextAlign(fg, AlignH_Right, AlignV_Bottom)
  addText(fg, fStat, 'SYNC #' .. tick .. '   build ' .. build, rx - padX, ry - ry * 0.015)
end
]==]

-- Config comes from explicit options (passed to start), never from globals --
-- DU's global table does not carry our values reliably.
local function buildConfig(opts)
  opts = opts or {}
  local debug = opts.debug
  if debug == nil then debug = true end
  local hud = opts.hud
  if hud == nil then hud = false end
  return {
    refreshSeconds = opts.refreshSeconds or 5,
    warnPct = opts.warnPct or 75,
    critPct = opts.critPct or 90,
    sortMode = opts.sortMode or "fill-desc",
    title = opts.title or "BASE INVENTORY",
    labelMode = opts.labelMode or "auto",
    debug = debug,
    hud = hud,
    build = opts.build or "dev",
  }
end

-- The board's link slots are DIRECT globals (slot1..slot10) referenced by name.
-- Undefined ones read as nil (no error).
local function rawSlots()
  local t = {}
  t[1] = slot1; t[2] = slot2; t[3] = slot3; t[4] = slot4; t[5] = slot5
  t[6] = slot6; t[7] = slot7; t[8] = slot8; t[9] = slot9; t[10] = slot10
  return t
end

-- Dense array of linked slots (nil/unlinked dropped) so # is reliable.
local function gatherSlots()
  local raw = rawSlots()
  local slots = {}
  for i = 1, MAX_SLOTS do
    if raw[i] ~= nil then slots[#slots + 1] = raw[i] end
  end
  return slots
end

-- Build the current run environment by scanning + classifying the slots.
local function env()
  local sc = M.classify(gatherSlots())
  return { screen = sc.screen, containers = sc.containers,
           config = M.config, tick = M._tick }
end

-- Print the class + name reported by every linked slot (diagnostics).
local function dumpSlots()
  local raw = rawSlots()
  for i = 1, MAX_SLOTS do
    local s = raw[i]
    if s ~= nil then
      local cls, nm = "?", "?"
      pcall(function() cls = tostring(s.getClass()) end)
      pcall(function() nm = tostring(s.getName()) end)
      dbg(string.format("slot%d: class=%s name=%s", i, cls, nm))
    end
  end
end

function M.start(opts)
  M.config = buildConfig(opts)
  M.debug = M.config.debug
  M._tick = 0
  dbg("===== Base Inventory Monitor build " .. tostring(M.config.build) .. " =====")
  dbg("onStart begin -- scanning slot1.." .. MAX_SLOTS)
  dumpSlots()
  local e = env()
  dbg(string.format("detected: screen=%s containers=%d",
      e.screen and "OK" or "MISSING", #e.containers))
  if e.screen then
    if e.screen.activate then pcall(function() e.screen.activate() end) end
    if e.screen.setRenderScript then
      pcall(function() e.screen.setRenderScript(M.RENDER_SCRIPT) end)
      dbg("screen.setRenderScript() installed")
    end
  end
  if M.config.hud and system and system.showScreen then
    pcall(function() system.showScreen(1) end)
    dbg("system.showScreen(1) called (HUD mirror)")
  end
  local data = M.run(e)
  dbg("run -> data len=" .. (data and #data or "nil"))
  if unit and unit.setTimer then
    unit.setTimer("refresh", M.config.refreshSeconds)
    dbg("timer 'refresh' set to " .. tostring(M.config.refreshSeconds) .. "s")
  end
  dbg("onStart done")
end

function M.tick()
  M.config = M.config or buildConfig()
  M._tick = (M._tick or 0) + 1
  local data = M.run(env())
  dbg("tick #" .. M._tick .. " -> data len=" .. (data and #data or "nil"))
end

function M.run(e)
  local cfg = e.config or {}
  local title = cfg.title or "BASE INVENTORY"
  local warnPct = cfg.warnPct or 75
  local critPct = cfg.critPct or 90

  -- Request a content sync on first run and every ~30s (updateContent is throttled
  -- to 1/30s; getContent() then returns fresh data on a later tick).
  local containers = e.containers or {}
  if e.tick == 0 or (e.tick % 6 == 0) then
    for _, c in ipairs(containers) do
      if c.updateContent then pcall(function() c.updateContent() end) end
    end
  end

  -- Cached system.getItem (items are static) for content-based labels.
  M._itemCache = M._itemCache or {}
  local cache = M._itemCache
  local function getItem(id)
    local v = cache[id]
    if v == nil then
      local it = nil
      if system and system.getItem then pcall(function() it = system.getItem(id) end) end
      cache[id] = it or false
      v = cache[id]
    end
    if v == false then return nil end
    return v
  end

  local rows = M.buildRows(containers, { getItem = getItem, labelMode = cfg.labelMode })
  M.sortRows(rows, cfg.sortMode or "fill-desc")
  local agg = M.aggregate(rows)
  local model = {
    title = title, warnPct = warnPct, critPct = critPct, tick = e.tick or 0,
    rows = rows, agg = agg, build = cfg.build,
  }

  -- Screen: feed data to the render script (setHTML is deprecated on DU screens).
  local data = M.buildScreenData(model)
  if e.screen and e.screen.setScriptInput then
    pcall(function() e.screen.setScriptInput(data) end)
  end
  -- HUD mirror (HTML) -- optional, off by default (it covers the whole view).
  if cfg.hud and system and system.setScreen then
    pcall(function() system.setScreen(M.renderHTML(model)) end)
  end
  return data
end

return M
