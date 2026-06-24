-- Base Inventory Monitor (Dual Universe) -- single source of truth.
-- Pure logic + DU bootstrap. Exposes global BIM so local tests can reach it.
BIM = BIM or {}
local M = BIM

-- Debug logging to the board console / game log (grep the log for "[BIM]").
-- Toggle off with the `debug` export.
local function dbg(msg)
  if M.debug == false then return end
  if _G.system and _G.system.print then
    _G.system.print("[BIM] " .. tostring(msg))
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

-- Read one linked container/hub handle into a row record.
local function readContainer(c, idx)
  local label = handleName(c, idx)
  local vol = c.getItemsVolume()
  local maxVol = c.getMaxVolume()
  local mass = c.getItemsMass()

  local pct = 0
  if maxVol and maxVol > 0 then pct = (vol / maxVol) * 100 end
  return { label = label, vol = vol or 0, maxVol = maxVol or 0,
           mass = mass or 0, pct = pct, ok = true }
end

-- Build rows from an array of container/hub handles (already filtered).
-- Each handle is labelled by its own getName(); a failed read becomes ok=false.
function M.buildRows(containers)
  local rows = {}
  for i = 1, #containers do
    local c = containers[i]
    if c ~= nil then
      local ok, row = pcall(readContainer, c, i)
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

  parts[#parts+1] = string.format('<div class="footer">SYNC #%d</div>', model.tick or 0)
  parts[#parts+1] = '</div></div>'
  return table.concat(parts)
end

local function buildConfig()
  local debug = _G.bimDebug
  if debug == nil then debug = true end
  return {
    refreshSeconds = _G.refreshSeconds or 5,
    warnPct = _G.warnPct or 75,
    critPct = _G.critPct or 90,
    sortMode = _G.sortMode or "fill-desc",
    title = _G.title or "BASE INVENTORY",
    debug = debug,
  }
end

-- Read the board's linkable slots (slot1..slot10) from the global env,
-- returning a dense array (nil/unlinked slots dropped) so # is reliable.
local function gatherSlots()
  local slots = {}
  for i = 1, MAX_SLOTS do
    local s = _G["slot" .. i]
    if s ~= nil then slots[#slots + 1] = s end
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
  for i = 1, MAX_SLOTS do
    local s = _G["slot" .. i]
    if s ~= nil then
      local cls, nm = "?", "?"
      pcall(function() cls = tostring(s.getClass()) end)
      pcall(function() nm = tostring(s.getName()) end)
      dbg(string.format("slot%d: class=%s name=%s", i, cls, nm))
    end
  end
end

function M.start()
  M.config = buildConfig()
  M.debug = M.config.debug
  M._tick = 0
  dbg("onStart begin -- scanning slot1.." .. MAX_SLOTS)
  dumpSlots()
  local e = env()
  dbg(string.format("detected: screen=%s containers=%d",
      e.screen and "OK" or "MISSING", #e.containers))
  if e.screen and e.screen.activate then
    pcall(function() e.screen.activate() end)
    dbg("screen.activate() called")
  end
  local html = M.run(e)
  dbg("run -> setHTML len=" .. (html and #html or "nil (no screen)"))
  if _G.unit and _G.unit.setTimer then
    _G.unit.setTimer("refresh", M.config.refreshSeconds)
    dbg("timer 'refresh' set to " .. tostring(M.config.refreshSeconds) .. "s")
  end
  dbg("onStart done")
end

function M.tick()
  M.config = M.config or buildConfig()
  M._tick = (M._tick or 0) + 1
  local html = M.run(env())
  dbg("tick #" .. M._tick .. " -> setHTML len=" .. (html and #html or "nil"))
end

function M.run(e)
  local screen = e.screen
  if not screen then return nil end
  local cfg = e.config or {}
  local title = cfg.title or "BASE INVENTORY"
  local warnPct = cfg.warnPct or 75
  local critPct = cfg.critPct or 90

  local rows = M.buildRows(e.containers or {})
  M.sortRows(rows, cfg.sortMode or "fill-desc")
  local agg = M.aggregate(rows)
  local html = M.renderHTML({
    title = title, warnPct = warnPct, critPct = critPct, tick = e.tick or 0,
    rows = rows, agg = agg,
  })
  screen.setHTML(html)
  return html
end

return M
