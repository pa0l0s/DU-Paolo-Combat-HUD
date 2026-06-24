# Generates screentest.config.json: a minimal isolation test for DU screens.
# It does NOT use the main module. It writes plain text to every linked element that
# has setHTML(), and prints detailed [BIMTEST] diagnostics to the Lua console.
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$stamp = (Get-Date).ToString("yyyy-MM-dd_HH:mm:ss")

$onStart = @'
system.print('[BIMTEST] build {STAMP} onStart begin')
local screens = 0
for i = 1, 10 do
  local s = _G['slot' .. i]
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
if unit and unit.setTimer then unit.setTimer('t', 2) end
'@.Replace('{STAMP}', $stamp)

$onTimer = @'
local n = 0
for i = 1, 10 do
  local s = _G['slot' .. i]
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
