# Generates BaseMonitor.config.json (Dual Universe programming-board import format)
# from baseinventory.lua, the single source of truth. Never edit the .json by hand.
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcLines = Get-Content -Path (Join-Path $here "baseinventory.lua")

# Strip trailing blank lines, then a trailing `return M` sentinel. The sentinel is
# required for dofile() in the local tests, but inlined into onStart it would end the
# chunk before BIM.start() runs.
$list = [System.Collections.Generic.List[string]]::new()
$srcLines | ForEach-Object { $list.Add($_) }
while ($list.Count -gt 0 -and $list[$list.Count - 1].Trim() -eq "") { $list.RemoveAt($list.Count - 1) }
if ($list.Count -gt 0 -and $list[$list.Count - 1].Trim() -eq "return M") { $list.RemoveAt($list.Count - 1) }
$source = ($list -join "`n")

# Incrementing build number (shared with screentest via .buildno) so you can confirm
# in-game which version is actually loaded.
$bnFile = Join-Path $here ".buildno"
$bn = 0
if (Test-Path $bnFile) { $bn = [int]((Get-Content -Raw $bnFile).Trim()) }
$bn = $bn + 1
Set-Content -Path $bnFile -Value $bn -Encoding ascii
$build = "$bn ($(Get-Date -Format 'HH:mm:ss'))"

# --export tunables (editable in the in-game board panel) declared as locals,
# then passed explicitly into BIM.start{} (DU's _G does not carry our values).
$exports = @'
local refreshSeconds = 5 --export: how often the screen refreshes (seconds)
local warnPct = 75 --export: warning threshold percent (yellow bar)
local critPct = 90 --export: critical threshold percent (pink pulsing bar)
local sortMode = "fill-desc" --export: fill-desc | fill-asc | name | none
local title = "BASE INVENTORY" --export: header title text
local bimDebug = true --export: print [BIM] diagnostics to the Lua console
local bimHud = false --export: also mirror the display to the player HUD (press F on the board; it covers the whole view)
'@.Trim()

# Printed FIRST, before anything else, so the Lua console shows the running build.
$banner = "system.print('[BIM] BUILD $build loaded -- this is the latest script')"

# Pass config explicitly (no _G); BIM.start() is the last statement of onStart.
$bridge = "BIM.start({ refreshSeconds = refreshSeconds, warnPct = warnPct, critPct = critPct, sortMode = sortMode, title = title, debug = bimDebug, hud = bimHud, build = '$build' })"

$onStartCode = $banner + "`n`n" + $exports + "`n`n" + $source + "`n`n" + $bridge
$onTimerCode = 'if timerId == "refresh" then BIM.tick() end'

# Slots: indices 0..9 -> slot1..slot10, plus the built-in negative slots.
$slots = [ordered]@{}
for ($i = 0; $i -lt 10; $i++) {
  $slots["$i"] = [ordered]@{ name = "slot$($i + 1)"; type = [ordered]@{ events = @(); methods = @() } }
}
$special = [ordered]@{ "-1" = "unit"; "-2" = "construct"; "-3" = "player"; "-4" = "system"; "-5" = "library" }
foreach ($k in $special.Keys) {
  $slots["$k"] = [ordered]@{ name = $special[$k]; type = [ordered]@{ events = @(); methods = @() } }
}

# Force single-element args to serialise as a JSON array (not an object).
$timerArgs = [System.Collections.ArrayList]::new()
[void]$timerArgs.Add([ordered]@{ variable = "*" })

$handlers = @(
  [ordered]@{
    code   = $onStartCode
    filter = [ordered]@{ args = @(); signature = "onStart()"; slotKey = "-1" }
    key    = "0"
  },
  [ordered]@{
    code   = $onTimerCode
    filter = [ordered]@{ args = $timerArgs; signature = "onTimer(timerId)"; slotKey = "-1" }
    key    = "1"
  }
)

$config = [ordered]@{
  slots    = $slots
  handlers = $handlers
  methods  = @()
  events   = @()
}

$json = $config | ConvertTo-Json -Depth 16
Set-Content -Path (Join-Path $here "BaseMonitor.config.json") -Value $json -Encoding utf8
Write-Host "Wrote BaseMonitor.config.json"
