# Generates screentest.config.json: a minimal isolation test for DU screens.
# It does NOT use the main module. It writes plain text to every linked element that
# has setHTML(), and prints detailed [BIMTEST] diagnostics to the Lua console.
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$bnFile = Join-Path $here ".buildno"
$bn = 0
if (Test-Path $bnFile) { $bn = [int]((Get-Content -Raw $bnFile).Trim()) }
$bn = $bn + 1
Set-Content -Path $bnFile -Value $bn -Encoding ascii
$stamp = "$bn ($(Get-Date -Format 'HH:mm:ss'))"

$onStart = @'
system.print('[BIMTEST] BUILD {STAMP} onStart begin')
-- DU link slots are DIRECT globals (slot1..slot10), NOT members of _G.
local slots = {}
slots[1]=slot1 slots[2]=slot2 slots[3]=slot3 slots[4]=slot4 slots[5]=slot5
slots[6]=slot6 slots[7]=slot7 slots[8]=slot8 slots[9]=slot9 slots[10]=slot10
local screens = 0
for i = 1, 10 do
  local s = slots[i]
  if s ~= nil then
    local cls = '?'; pcall(function() cls = tostring(s.getClass()) end)
    local nm  = '?'; pcall(function() nm  = tostring(s.getName()) end)
    local hasHTML = (type(s.setHTML) == 'function')
    local hasVol  = (type(s.getItemsVolume) == 'function')
    system.print(string.format('[BIMTEST] slot%d class=%s name=%s setHTML=%s vol=%s',
      i, cls, nm, tostring(hasHTML), tostring(hasVol)))
    if hasHTML then
      pcall(function() if s.activate then s.activate() end end)
      local html = "<div style='width:100%;height:100%;background:#0d0211;color:#00f3ff;font-family:monospace'>"
        .. "<div style='font-size:60px;padding:40px'>BIMTEST OK</div>"
        .. "<div style='font-size:30px;padding:0 40px;color:#ff007f'>build {STAMP}</div>"
        .. "<div style='font-size:24px;padding:20px 40px;color:#ffffff'>setHTML works on slot" .. i .. "</div>"
        .. "</div>"
      local ok, err = pcall(function() s.setHTML(html) end)
      system.print(string.format('[BIMTEST] setHTML slot%d ok=%s err=%s', i, tostring(ok), tostring(err)))
      screens = screens + 1
    end
  end
end
system.print('[BIMTEST] screens written = ' .. screens)
if screens == 0 then system.print('[BIMTEST] NO element with setHTML found -- is a Screen linked?') end
-- Also mirror to the HUD (works when you run the board with F).
if system.setScreen then
  pcall(function() system.showScreen(1) end)
  pcall(function() system.setScreen("<div style='color:#fffb00;background:#0d0211;font-family:monospace;font-size:50px;padding:40px'>BIMTEST HUD build {STAMP}</div>") end)
  system.print('[BIMTEST] HUD setScreen attempted')
end
if unit and unit.setTimer then unit.setTimer('t', 2) end
'@.Replace('{STAMP}', $stamp)

$onTimer = @'
local slots = {}
slots[1]=slot1 slots[2]=slot2 slots[3]=slot3 slots[4]=slot4 slots[5]=slot5
slots[6]=slot6 slots[7]=slot7 slots[8]=slot8 slots[9]=slot9 slots[10]=slot10
local n = 0
for i = 1, 10 do
  local s = slots[i]
  if s ~= nil and type(s.setHTML) == 'function' then
    pcall(function() if s.activate then s.activate() end end)
    local html = "<div style='width:100%;height:100%;background:#120136;color:#fffb00;font-family:monospace'>"
      .. "<div style='font-size:60px;padding:40px'>BIMTEST TICK</div>"
      .. "<div style='font-size:26px;padding:0 40px;color:#ffffff'>timer + setHTML both work</div>"
      .. "</div>"
    pcall(function() s.setHTML(html) end)
    n = n + 1
  end
end
system.print('[BIMTEST] tick fired, screens=' .. n)
'@

# Slots: 0..9 -> slot1..slot10 plus the built-in negative slots.
$slots = [ordered]@{}
for ($i = 0; $i -lt 10; $i++) {
  $slots["$i"] = [ordered]@{ name = "slot$($i + 1)"; type = [ordered]@{ events = @(); methods = @() } }
}
$special = [ordered]@{ "-1" = "unit"; "-2" = "construct"; "-3" = "player"; "-4" = "system"; "-5" = "library" }
foreach ($k in $special.Keys) {
  $slots["$k"] = [ordered]@{ name = $special[$k]; type = [ordered]@{ events = @(); methods = @() } }
}

$timerArgs = [System.Collections.ArrayList]::new()
[void]$timerArgs.Add([ordered]@{ variable = "*" })

$handlers = @(
  [ordered]@{ code = $onStart; filter = [ordered]@{ args = @(); signature = "onStart()"; slotKey = "-1" }; key = "0" },
  [ordered]@{ code = $onTimer; filter = [ordered]@{ args = $timerArgs; signature = "onTimer(timerId)"; slotKey = "-1" }; key = "1" }
)

$config = [ordered]@{ slots = $slots; handlers = $handlers; methods = @(); events = @() }
$config | ConvertTo-Json -Depth 16 | Set-Content -Path (Join-Path $here "screentest.config.json") -Encoding utf8
Write-Host "Wrote screentest.config.json (build $stamp)"
