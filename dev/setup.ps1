param([switch]$ExportTemplates)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
$toolPath = Join-Path $projectPath 'tools'
New-Item -ItemType Directory -Force -Path $toolPath | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $toolPath '.gdignore') | Out-Null
$releaseUrl = 'https://github.com/godotengine/godot-builds/releases/download/4.6-stable'
if (-not (Test-Path -LiteralPath (Join-Path $toolPath 'Godot_v4.6-stable_win64.exe'))) {
    Invoke-WebRequest -Uri "$releaseUrl/Godot_v4.6-stable_win64.exe.zip" -OutFile (Join-Path $toolPath 'godot.zip')
    Expand-Archive -LiteralPath (Join-Path $toolPath 'godot.zip') -DestinationPath $toolPath -Force
}
if ($ExportTemplates -and -not (Test-Path -LiteralPath (Join-Path $toolPath 'export/templates/windows_release_x86_64.exe'))) {
    Invoke-WebRequest -Uri "$releaseUrl/Godot_v4.6-stable_export_templates.tpz" -OutFile (Join-Path $toolPath 'templates.zip')
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archiveFile = [IO.Compression.ZipFile]::OpenRead((Join-Path $toolPath 'templates.zip'))
    try {
        foreach ($entry in $archiveFile.Entries) {
            if ($entry.FullName -match '^templates/windows_(debug|release)_x86_64(_console)?\.exe$') {
                $targetPath = Join-Path $toolPath ('export/' + $entry.FullName)
                New-Item -ItemType Directory -Force -Path (Split-Path $targetPath -Parent) | Out-Null
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $targetPath, $true)
            }
        }
    } finally { $archiveFile.Dispose() }
}
& (Join-Path $projectPath 'native/build.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Native bridge build failed' }
