# Bundles src/ Lua modules into autoconf .conf files.
# Generated .conf files are artifacts -- never hand-edit them.
param(
  [string]$Custom = "E:\GRY\My Dual Universe\Game\data\lua\autoconf\custom"
)
$ErrorActionPreference = "Stop"
$root   = $PSScriptRoot
$srcDir = Join-Path $root "src"

# Bump shared build number.
$buildFile = Join-Path $root ".buildno"
$build = 1
if (Test-Path $buildFile) { $build = [int](Get-Content $buildFile) + 1 }
Set-Content -Path $buildFile -Value $build

# Auto-resolve the transitive require() closure of an entry module by scanning
# src/ for require('core.x'|'du.x'|'render.x'|'bootstrap.x') -- so the bundle's
# module list can never drift out of sync with the actual dependencies.
# External modules (e.g. dkjson) have no src file and are left to DU's real require.
function Resolve-Deps([string]$entry) {
  $seen = @{}
  $result = New-Object System.Collections.Generic.List[string]
  $queue = New-Object System.Collections.Generic.Queue[string]
  $queue.Enqueue($entry)
  while ($queue.Count -gt 0) {
    $name = $queue.Dequeue()
    if ($seen.ContainsKey($name)) { continue }
    $seen[$name] = $true
    $file = Join-Path $srcDir (($name -replace '\.', '/') + ".lua")
    if (-not (Test-Path $file)) { continue }
    [void]$result.Add($name)
    $code = Get-Content $file -Raw
    foreach ($mt in [regex]::Matches($code, 'require\([''"]([\w.]+)[''"]\)')) {
      $dep = $mt.Groups[1].Value
      if ($dep -match '^(core|du|render|bootstrap)\.' -and -not $seen.ContainsKey($dep)) {
        $queue.Enqueue($dep)
      }
    }
  }
  return $result
}

# Wrap modules in a require-shim that falls back to DU's real require (dkjson etc.).
# Modules are auto-resolved from $entry; the $modules arg is ignored (kept for compat).
function Build-Bundle([string[]]$modules, [string]$entry, [string]$bootLua) {
  $sb = [System.Text.StringBuilder]::new()
  [void]$sb.AppendLine("-- PVPHud bundle (build $build) -- GENERATED, do not edit")
  [void]$sb.AppendLine("local __realRequire = require")
  [void]$sb.AppendLine("local __mods, __cache = {}, {}")
  [void]$sb.AppendLine("local function require(name)")
  [void]$sb.AppendLine("  if __cache[name] ~= nil then return __cache[name] end")
  [void]$sb.AppendLine("  local loader = __mods[name]")
  [void]$sb.AppendLine("  if loader then local m = loader(); __cache[name] = m; return m end")
  [void]$sb.AppendLine("  return __realRequire(name)")
  [void]$sb.AppendLine("end")
  foreach ($m in (Resolve-Deps $entry)) {
    $file = Join-Path $srcDir (($m -replace '\.', '/') + ".lua")
    $code = (Get-Content $file -Raw).TrimEnd()
    [void]$sb.AppendLine("__mods['$m'] = function(...)")
    [void]$sb.AppendLine($code)
    [void]$sb.AppendLine("end")
  }
  [void]$sb.AppendLine("local __entry = require('$entry')")
  [void]$sb.AppendLine($bootLua)
  return $sb.ToString()
}

# Indent a block for embedding under a YAML 'lua: |' literal scalar.
function Indent([string]$text, [int]$spaces) {
  $pad = " " * $spaces
  return (($text -split "`r?`n") | ForEach-Object { if ($_ -eq "") { "" } else { $pad + $_ } }) -join "`n"
}

function Write-Conf([string]$name, [string]$confText) {
  $out = Join-Path $root $name
  Set-Content -Path $out -Value $confText -Encoding UTF8
  if (Test-Path $Custom) { Copy-Item $out (Join-Path $Custom $name) -Force }
  Write-Host "Wrote $name (build $build)"
}

# --- Phase 1 target: self-test ---
$modules = @('core.format', 'core.theme', 'core.channel', 'bootstrap_smoke')
$bootLua = "system.showScreen(1)`nfunction __pvphud_render() __entry.start({ system = system, build = $build, db = db_1, codec = (db_1 ~= nil) and require('dkjson') or nil }) end"
$bundle  = Build-Bundle $modules 'bootstrap_smoke' $bootLua

$conf = @"
name: PVPHud Self-Test v$build
slots:
    core:
        class: CoreUnit
    db:
        class: DataBank
        select: manual
handlers:
    unit:
        onStart:
            lua: |
$(Indent $bundle 16)
    system:
        onUpdate:
            lua: |
                __pvphud_render()
"@

Write-Conf "pvphud_selftest.conf" $conf

# --- Gunner Seat HUD target ---
$gunnerModules = @(
  'core.format', 'core.theme', 'core.channel', 'core.ballistics', 'core.weapons',
  'core.dps', 'core.threat', 'core.tracking', 'du.weapon', 'du.radar', 'du.construct',
  'render.widgets', 'render.ar_layer', 'render.gunner_view', 'bootstrap_gunner'
)
$gunnerBoot = @"
system.showScreen(1)
GunnerApp = require('bootstrap_gunner').start({ system = system, construct = construct, library = library, weapon = weapon, radar = radar_1, db = db_1, codec = (db_1 ~= nil) and require('dkjson') or nil, build = $build })
unit.setTimer('dpsTick', 1)
"@
$gunnerBundle = Build-Bundle $gunnerModules 'bootstrap_gunner' $gunnerBoot

# Per-weapon hit/miss handlers (weapon_1 .. weapon_6)
$weaponHandlers = ""
for ($i = 1; $i -le 6; $i++) {
  $weaponHandlers += @"
    weapon_$($i):
        onHit(targetId,damage):
            lua: |
                if GunnerApp then GunnerApp.onWeaponHit(targetId, damage) end
        onMissed(targetId):
            lua: |
                if GunnerApp then GunnerApp.onWeaponMiss(targetId) end
"@
  $weaponHandlers += "`n"
}

$gunnerConf = @"
name: Gunner Seat HUD (Retrosyncwave) v$build
slots:
    core:
        class: CoreUnit
    weapon:
        class: WeaponUnit
        select: manual
    radar:
        class: RadarPVPUnit
        select: manual
    db:
        class: DataBank
        select: manual
handlers:
    unit:
        onStart:
            lua: |
$(Indent $gunnerBundle 16)
        tick:
            args: ["dpsTick"]
            lua: |
                if GunnerApp then GunnerApp.onTick() end
    system:
        onUpdate:
            lua: |
                if GunnerApp then GunnerApp.onUpdate() end
    core:
        onStressChanged(stress):
            lua: |
                if GunnerApp then GunnerApp.onDamage(stress) end
$weaponHandlers
"@

Write-Conf "gunner_seat_hud.conf" $gunnerConf

# --- Remote Controller HUD target ---
$ctrlModules = @(
  'core.format', 'core.theme', 'core.channel', 'core.resist', 'core.ballistics',
  'du.shield', 'du.flight', 'render.widgets', 'render.controller_view',
  'bootstrap_controller'
)
$ctrlBoot = @"
system.showScreen(1)
CtrlApp = require('bootstrap_controller').start({ system = system, construct = construct, unit = unit, shield = shield_1, db = db_1, codec = (db_1 ~= nil) and require('dkjson') or nil, build = $build })
"@
$ctrlBundle = Build-Bundle $ctrlModules 'bootstrap_controller' $ctrlBoot

$ctrlConf = @"
name: Remote Controller HUD (Retrosyncwave) v$build
slots:
    core:
        class: CoreUnit
    shield:
        class: ShieldGeneratorUnit
        select: manual
    db:
        class: DataBank
        select: manual
handlers:
    unit:
        onStart:
            lua: |
$(Indent $ctrlBundle 16)
                -- Flight control (current DU Navigator API, per ArchHUD/GFL). Bare
                -- globals so the system action/flush handlers can read them.
                Nav = Navigator.new(system, core, unit)
                unit.hideWidget() -- hide the default control widget (it fights throttle/brake)
                pitchInput = 0
                rollInput = 0
                yawInput = 0
                brakeInput = 0
                local brakeToggle = true --export: Brake key toggles on/off (true) or is momentary hold (false)
                brakeToggleMode = brakeToggle
    system:
        onFlush:
            lua: |
                local rotationSpeed = 2 --export: flight rotation speed (rad/s)
                local torqueFactor = 1 --export: torque factor to reach rotationSpeed (high = unstable)
                local worldUp = vec3(construct.getWorldOrientationUp())
                local worldForward = vec3(construct.getWorldOrientationForward())
                local worldRight = vec3(construct.getWorldOrientationRight())
                local currentAngularVelocity = vec3(construct.getWorldAngularVelocity())
                local targetAngularVelocity = pitchInput * worldRight + rollInput * worldForward + yawInput * worldUp
                targetAngularVelocity = rotationSpeed * targetAngularVelocity:normalize()
                local angularAccel = torqueFactor * (targetAngularVelocity - currentAngularVelocity)
                local airAcceleration = vec3(construct.getWorldAirFrictionAngularAcceleration())
                angularAccel = angularAccel - airAcceleration
                -- Modern split API (per ArchHUD/GFL). Do NOT mix the old combined
                -- setEngineCommand here -- it touches the linear-force channel with a
                -- zero vector and zeroes the brake force.
                Nav:setEngineTorqueCommand('torque', angularAccel, 1, 'airfoil', '', '', 1)
                -- Full flight command sequence mirroring GFL_Pilot's byThrottle path,
                -- in the same ORDER and with the same companion commands (lateral,
                -- vertical priority subtags, brake, boosters). Issuing the complete set
                -- is what lets the Navigator resolve the brake.
                local navCom = Nav.axisCommandManager
                -- longitudinal thrust (independent of braking)
                local longTags = 'thrust analog longitudinal'
                Nav:setEngineForceCommand(longTags, navCom:composeAxisAccelerationFromThrottle(longTags, axisCommandId.longitudinal), 1)
                -- Brake: official DU default formula (per paolo). setEngineForceCommand('brake')
                -- takes an ACCELERATION (not getMaxBrake force). The flat factor brings the
                -- ship fully to 0 (a force-based brake stalls around ~5 km/h).
                local brakeSpeedFactor = 3 --export: brake force scales with brakeSpeedFactor * velocity
                local brakeFlatFactor = 1 --export: flat brake force; brings the ship fully to a stop
                brakeSpeedFactor = math.max(brakeSpeedFactor, 0.01)
                brakeFlatFactor = math.max(brakeFlatFactor, 0.01)
                local cVel = vec3(core.getWorldVelocity())
                local cVelDir = vec3(core.getWorldVelocity()):normalize()
                local brakeAcceleration = -brakeInput * (brakeSpeedFactor * cVel + brakeFlatFactor * cVelDir)
                Nav:setEngineForceCommand('brake', brakeAcceleration)
                -- lateral strafe
                local latTags = 'thrust analog lateral'
                Nav:setEngineForceCommand(latTags, navCom:composeAxisAccelerationFromThrottle(latTags, axisCommandId.lateral), 1)
                -- vertical (with airfoil/ground priority subtags, per GFL)
                local vertTags = 'thrust analog vertical'
                Nav:setEngineForceCommand(vertTags, navCom:composeAxisAccelerationFromThrottle(vertTags, axisCommandId.vertical), 1, 'airfoil', 'ground', '', 1)
                -- boosters / rockets (fires retro-rockets)
                Nav:setBoosterCommand('rocket_engine')
                if CtrlApp then CtrlApp.onFlush() end
        onUpdate:
            lua: |
                Nav:update()
                if CtrlApp then CtrlApp.onUpdate(brakeInput) end
        onActionStart:
            args: [forward]
            lua: pitchInput = pitchInput - 1
        onActionStop:
            args: [forward]
            lua: pitchInput = pitchInput + 1
        onActionStart:
            args: [backward]
            lua: pitchInput = pitchInput + 1
        onActionStop:
            args: [backward]
            lua: pitchInput = pitchInput - 1
        onActionStart:
            args: [left]
            lua: rollInput = rollInput - 1
        onActionStop:
            args: [left]
            lua: rollInput = rollInput + 1
        onActionStart:
            args: [right]
            lua: rollInput = rollInput + 1
        onActionStop:
            args: [right]
            lua: rollInput = rollInput - 1
        onActionLoop:
            args: [up]
            lua: Nav.axisCommandManager:updateThrottleCommand(axisCommandId.vertical, 0.05)
        onActionLoop:
            args: [down]
            lua: Nav.axisCommandManager:updateThrottleCommand(axisCommandId.vertical, -0.05)
        onActionStart:
            args: [yawright]
            lua: yawInput = yawInput - 1
        onActionStop:
            args: [yawright]
            lua: yawInput = yawInput + 1
        onActionStart:
            args: [yawleft]
            lua: yawInput = yawInput + 1
        onActionStop:
            args: [yawleft]
            lua: yawInput = yawInput - 1
        onActionStart:
            args: [brake]
            lua: |
                if brakeToggleMode then brakeInput = 1 - brakeInput else brakeInput = 1 end
        onActionStop:
            args: [brake]
            lua: |
                if not brakeToggleMode then brakeInput = 0 end
        onActionStart:
            args: [stopengines]
            lua: Nav.axisCommandManager:setThrottleCommand(axisCommandId.longitudinal, 0)
        onActionLoop:
            args: [speedup]
            lua: Nav.axisCommandManager:updateThrottleCommand(axisCommandId.longitudinal, 0.05)
        onActionLoop:
            args: [speeddown]
            lua: Nav.axisCommandManager:updateThrottleCommand(axisCommandId.longitudinal, -0.05)
        onActionStart:
            args: [option6]
            lua: |
                if CtrlApp then CtrlApp.toggleAuto() end
        onActionStart:
            args: [option8]
            lua: |
                if CtrlApp then CtrlApp.toggleVent() end
"@

Write-Conf "remote_controller_hud.conf" $ctrlConf
