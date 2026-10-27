param([ValidateSet('gl_compatibility','mobile','forward_plus')][string]$Renderer = 'gl_compatibility')
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = Join-Path $projectPath 'tools/Godot_v4.6-stable_win64.exe'
$startInfo.Arguments = '--path "' + $projectPath + '" --rendering-method ' + $Renderer + ' -- --test-mode --benchmark'
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$farmProcess = [Diagnostics.Process]::Start($startInfo)
$samples = @()
$previousCpu = 0.0
$previousTime = [DateTime]::UtcNow
while (-not $farmProcess.HasExited) {
    Start-Sleep -Seconds 1
    if ($farmProcess.HasExited) { break }
    $farmProcess.Refresh()
    $currentTime = [DateTime]::UtcNow
    $cpuSeconds = $farmProcess.TotalProcessorTime.TotalSeconds
    $samples += [pscustomobject]@{
        second = $samples.Count + 1
        cpu_total_percent = [Math]::Round(100 * ($cpuSeconds - $previousCpu) / ($currentTime - $previousTime).TotalSeconds / [Environment]::ProcessorCount, 3)
        working_set_mb = [Math]::Round($farmProcess.WorkingSet64 / 1MB, 2)
        private_mb = [Math]::Round($farmProcess.PrivateMemorySize64 / 1MB, 2)
    }
    $previousCpu = $cpuSeconds
    $previousTime = $currentTime
}
$samples | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $projectPath "build/process-$Renderer.json") -Encoding utf8
if ($farmProcess.ExitCode -ne 0) { throw 'Benchmark process failed' }
