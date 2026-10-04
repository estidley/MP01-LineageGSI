param([string]$Serial)
$ErrorActionPreference = 'Stop'
$mp01RepoRoot = Split-Path -Parent $PSScriptRoot
$mp01DeviceDir = Join-Path $mp01RepoRoot '.local-device'
$mp01DeviceLines = @(& adb devices)
if ($LASTEXITCODE -ne 0) { throw 'ADB could not enumerate devices.' }
$mp01ReadyDevices = @($mp01DeviceLines | ForEach-Object {
    if ($_ -match '^([^\s]+)\s+device\s*$') { $Matches[1] }
})
if ($Serial) {
    if ($Serial -notin $mp01ReadyDevices) { throw 'The selected phone is not authorized and online.' }
} elseif ($mp01ReadyDevices.Count -eq 1) {
    $Serial = $mp01ReadyDevices[0]
} else {
    throw 'Connect and authorize exactly one phone, or specify -Serial.'
}
function Read-Mp01Property([string]$Property) {
    $mp01Value = & adb -s $Serial shell getprop $Property
    if ($LASTEXITCODE -ne 0) { throw "Unable to read $Property" }
    return ($mp01Value -join "`n").Trim()
}
$mp01Properties = [ordered]@{}
foreach ($mp01Property in @(
    'ro.product.model', 'ro.product.manufacturer', 'ro.product.device',
    'ro.product.board', 'ro.hardware', 'ro.board.platform',
    'ro.product.cpu.abilist', 'ro.build.fingerprint',
    'ro.build.version.release', 'ro.build.version.sdk',
    'ro.build.version.security_patch', 'ro.vendor.build.fingerprint',
    'ro.vndk.version', 'ro.treble.enabled', 'ro.boot.flash.locked',
    'ro.boot.verifiedbootstate', 'ro.boot.vbmeta.device_state', 'ro.boot.slot_suffix'
)) {
    $mp01Properties[$mp01Property] = Read-Mp01Property $mp01Property
}
if ($mp01Properties['ro.product.model'] -notmatch '^MP01$') {
    throw "Expected model MP01; received $($mp01Properties['ro.product.model']). Inspect before proceeding."
}
New-Item -ItemType Directory -Path $mp01DeviceDir -Force | Out-Null
$mp01Properties | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $mp01DeviceDir 'properties.json') -Encoding utf8
& adb -s $Serial shell dumpsys input | Set-Content -LiteralPath (Join-Path $mp01DeviceDir 'input.txt') -Encoding utf8
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect Android input devices.' }
& adb -s $Serial shell df -h /data /system | Set-Content -LiteralPath (Join-Path $mp01DeviceDir 'storage.txt') -Encoding utf8
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect device storage.' }
$mp01Properties | ConvertTo-Json
Write-Host "Read-only device report saved in $mp01DeviceDir"
