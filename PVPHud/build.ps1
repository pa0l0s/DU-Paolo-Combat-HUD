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
