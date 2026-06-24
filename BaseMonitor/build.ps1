# Generates BaseMonitor.conf from baseinventory.lua (single source of truth).
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Get-Content -Raw -Path (Join-Path $here "baseinventory.lua")

# Strip trailing "return M" (needed for dofile() in tests, not in DU runtime).
$srcLines = $src -split "`r?`n"
# Remove the last non-empty "return M" line if present
$srcLines = $srcLines | Where-Object { $_.Trim() -ne "return M" }

# Indent every source line by 16 spaces to nest under "lua: |".
$indented = ($srcLines | ForEach-Object { "                " + $_ }) -join "`n"

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
$indented
                BIM.start()
        onTimer:
            args:
              - timerId: refresh
            lua: |
                BIM.tick()
"@

Set-Content -Path (Join-Path $here "BaseMonitor.conf") -Value $conf -Encoding utf8
Write-Host "Wrote BaseMonitor.conf"
