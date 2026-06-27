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

# Wrap modules in a require-shim that falls back to DU's real require (dkjson etc.).
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
  foreach ($m in $modules) {
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
name: PVPHud Self-Test
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
name: Gunner Seat HUD (Retrosyncwave)
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
CtrlApp = require('bootstrap_controller').start({ system = system, construct = construct, shield = shield_1, radar = radar_1, db = db_1, codec = (db_1 ~= nil) and require('dkjson') or nil, build = $build })
"@
$ctrlBundle = Build-Bundle $ctrlModules 'bootstrap_controller' $ctrlBoot

$ctrlConf = @"
name: Remote Controller HUD (Retrosyncwave)
slots:
    core:
        class: CoreUnit
    shield:
        class: ShieldGeneratorUnit
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
$(Indent $ctrlBundle 16)
    system:
        onUpdate:
            lua: |
                if CtrlApp then CtrlApp.onUpdate() end
        onFlush:
            lua: |
                if CtrlApp then CtrlApp.onFlush() end
        actionStart:
            args: ["option6"]
            lua: |
                if CtrlApp then CtrlApp.toggleAuto() end
        actionStart:
            args: ["option8"]
            lua: |
                if CtrlApp then CtrlApp.toggleVent() end
"@

Write-Conf "remote_controller_hud.conf" $ctrlConf
