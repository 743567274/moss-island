param([switch]$Desktop)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
$enginePath = Join-Path $projectPath 'tools/Godot_v4.6-stable_win64_console.exe'
function Invoke-GodotCheck {
    param([string[]]$EngineArgs)
    $engineOutput = & $enginePath @EngineArgs 2>&1
    $engineExit = $LASTEXITCODE
    $engineOutput | Write-Output
    if ($engineExit -ne 0 -or (($engineOutput -join "`n") -match '(?m)SCRIPT ERROR|SHADER ERROR|^ERROR:|Assertion failed')) {
        throw 'Godot validation reported a runtime, assertion or shader error'
    }
}

Invoke-GodotCheck @('--headless','--path',$projectPath,'--script','tests/test_corn.gd')
if ($LASTEXITCODE -ne 0) { throw 'Core tests failed' }
Invoke-GodotCheck @('--headless','--path',$projectPath,'--script','tests/test_weather.gd')
Invoke-GodotCheck @('--headless','--path',$projectPath,'--script','tests/test_county_weather.gd')
if ($LASTEXITCODE -ne 0) { throw 'Weather tests failed' }
Invoke-GodotCheck @('--headless','--path',$projectPath,'--script','tests/test_map_modules.gd')
Invoke-GodotCheck @('--headless','--path',$projectPath,'--','--test-mode','--integration')
if ($LASTEXITCODE -ne 0) { throw 'Integration failed' }
Invoke-GodotCheck @('--headless','--path',$projectPath,'--script','tests/test_scene_revision.gd')
if ($LASTEXITCODE -ne 0) { throw 'Scene revision tests failed' }
Invoke-GodotCheck @('--headless','--path',$projectPath,'--','--test-mode','--environment-test')
if ($LASTEXITCODE -ne 0) { throw 'Environment preview test failed' }
Invoke-GodotCheck @('--headless','--path',$projectPath,'--script','tests/test_performance.gd')
if ($LASTEXITCODE -ne 0) { throw 'Performance regression tests failed' }
Invoke-GodotCheck @('--headless','--path',$projectPath,'--script','tests/test_environment_v2.gd')
if ($LASTEXITCODE -ne 0) { throw 'Environment V2 tests failed' }
if ($Desktop) {
    Invoke-GodotCheck @('--path',$projectPath,'--rendering-method','mobile','--rendering-driver','vulkan','--script','tests/test_corn_render.gd')
    Invoke-GodotCheck @('--path',$projectPath,'--rendering-method','mobile','--rendering-driver','vulkan','--script','tests/test_map_render.gd')
    & (Join-Path $projectPath 'native/build.ps1')
    $compilerPath = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    & $compilerPath /nologo /target:exe /main:LocationFallbackTest /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Device.dll /reference:System.Web.Extensions.dll "/out:$projectPath\build\LocationFallbackTest.exe" "$projectPath\native\TrayHost.cs" "$projectPath\tests\LocationFallbackTest.cs"
    if ($LASTEXITCODE -ne 0) { throw 'Native location test build failed' }
    & "$projectPath/build/LocationFallbackTest.exe"
    if ($LASTEXITCODE -ne 0) { throw 'Native location tests failed' }
    Invoke-GodotCheck @('--path',$projectPath,'--','--test-mode','--desktop-test')
    if ($LASTEXITCODE -ne 0) { throw 'Desktop window test failed' }
}
