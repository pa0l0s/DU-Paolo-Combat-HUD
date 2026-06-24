# Generates BaseMonitor.conf from baseinventory.lua (single source of truth).
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Get-Content -Raw -Path (Join-Path $here "baseinventory.lua")

# Strip ONLY the trailing "return M" sentinel (Fix 2: harden strip).
$srcLines = $src -split "`r?`n"
# Drop trailing blank lines, then strip the last line if it equals "return M".
while ($srcLines.Count -gt 0 -and $srcLines[-1].Trim() -eq "") {
    $srcLines = $srcLines[0..($srcLines.Count - 2)]
}
if ($srcLines.Count -gt 0 -and $srcLines[-1].Trim() -eq "return M") {
    $srcLines = $srcLines[0..($srcLines.Count - 2)]
}

# Indent every source line by 16 spaces to nest under "lua: |".
$indented = ($srcLines | ForEach-Object { "                " + $_ }) -join "`n"

# Fix 1: five --export local declarations (DU editable tunables).
$exportLocals = @"
                local refreshSeconds = 5 --export: how often the screen refreshes (seconds)
                local warnPct = 75 --export: warning threshold percent (yellow bar)
                local critPct = 90 --export: critical threshold percent (pink pulsing bar)
                local sortMode = "fill-desc" --export: fill-desc | fill-asc | name | none
                local title = "BASE INVENTORY" --export: header title text
"@

# Fix 1: bridge that copies export locals into globals so buildConfig() picks them up.
$bridge = @"
                _G.refreshSeconds = refreshSeconds
                _G.warnPct = warnPct
                _G.critPct = critPct
                _G.sortMode = sortMode
                _G.title = title
                BIM.start()
"@

$slots = @"
slots:
    core:
        class: CoreUnit
    screen:
        class: ScreenUnit
"@
for ($i = 1; $i -le 24; $i++) {
  $slots += @"

    container$i`:
        class: ItemContainer
        select: manual
"@
}

$conf = @"
name: Base Inventory Monitor (Synthwave)

$slots
handlers:
    unit:
        onStart:
            lua: |
$exportLocals
$indented
$bridge
        onTimer:
            args:
              - timerId: refresh
            lua: |
                BIM.tick()
"@

Set-Content -Path (Join-Path $here "BaseMonitor.conf") -Value $conf -Encoding utf8
Write-Host "Wrote BaseMonitor.conf"
