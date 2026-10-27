param([switch]$SkipTests)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
& "$PSScriptRoot/setup.ps1" -ExportTemplates
$enginePath = Join-Path $projectPath 'tools/Godot_v4.6-stable_win64_console.exe'
New-Item -ItemType Directory -Force -Path (Join-Path $projectPath 'build') | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $projectPath 'build/.gdignore') | Out-Null
& $enginePath --headless --editor --path $projectPath --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
if (-not $SkipTests) {
    & $enginePath --headless --path $projectPath --script tests/test_corn.gd
    if ($LASTEXITCODE -ne 0) { throw 'Core tests failed' }
}
$cropPackages = Get-ChildItem -LiteralPath (Join-Path $projectPath 'data/crops') -Directory
foreach ($package in $cropPackages) {
    $rawDirectory = Join-Path $package.FullName 'raw'
    New-Item -ItemType Directory -Force -Path $rawDirectory | Out-Null
    Get-ChildItem -LiteralPath $package.FullName -Filter '*.png' -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $rawDirectory ($_.Name+'.bin')) -Force }
}
New-Item -ItemType Directory -Force -Path (Join-Path $projectPath 'build') | Out-Null
& $enginePath --headless --path $projectPath --export-release 'Windows Desktop'
if ($LASTEXITCODE -ne 0) { throw 'Windows export failed' }
Copy-Item -LiteralPath (Join-Path $projectPath 'native/TrayHost.exe') -Destination (Join-Path $projectPath 'build/MossIsland.exe') -Force
Copy-Item -LiteralPath (Join-Path $projectPath 'native/DesktopBridge.exe') -Destination (Join-Path $projectPath 'build/DesktopBridge.exe') -Force
Copy-Item -LiteralPath (Join-Path $projectPath 'LICENSE') -Destination (Join-Path $projectPath 'build/LICENSE') -Force
Copy-Item -LiteralPath (Join-Path $projectPath 'ASSETS.md') -Destination (Join-Path $projectPath 'build/ASSETS.md') -Force
Copy-Item -LiteralPath (Join-Path $projectPath 'docs/THIRD_PARTY.md') -Destination (Join-Path $projectPath 'build/THIRD_PARTY.md') -Force
Copy-Item -LiteralPath (Join-Path $projectPath 'docs/运行说明.txt') -Destination (Join-Path $projectPath 'build/运行说明.txt') -Force
New-Item -ItemType Directory -Force -Path (Join-Path $projectPath 'build/third-party') | Out-Null
Get-ChildItem -LiteralPath (Join-Path $projectPath 'docs/third-party') -File | Copy-Item -Destination (Join-Path $projectPath 'build/third-party') -Force
foreach ($package in $cropPackages) {
    $destination = Join-Path $projectPath ('build/crops/'+$package.Name)
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Get-ChildItem -LiteralPath $package.FullName -File | Where-Object { $_.Extension -in '.json','.png' } | Copy-Item -Destination $destination -Force
}
Write-Output "Build ready: $projectPath\build\MossIsland.exe"
