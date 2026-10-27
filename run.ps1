$ErrorActionPreference = 'Stop'
$buildPath = Join-Path $PSScriptRoot 'build/MossIsland.exe'
if (Test-Path -LiteralPath $buildPath) {
    Start-Process -FilePath $buildPath -WorkingDirectory (Split-Path $buildPath -Parent)
} else {
    & (Join-Path $PSScriptRoot 'dev/setup.ps1')
    Start-Process -FilePath (Join-Path $PSScriptRoot 'tools/Godot_v4.6-stable_win64.exe') -ArgumentList @('--path', ('"' + $PSScriptRoot + '"')) -WorkingDirectory $PSScriptRoot
}
