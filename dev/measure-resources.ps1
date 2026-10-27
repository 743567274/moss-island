param([int]$Seconds=10,[string]$OutputPath='build/resource-sample.json')
$ErrorActionPreference='Stop'
$sampleProcesses=@(Get-Process -Name MossImmersive,MossCompanion,MossIsland,DesktopBridge -ErrorAction SilentlyContinue)
$cpuBefore=@{}
foreach($item in $sampleProcesses) { $cpuBefore[$item.Id]=$item.CPU }
$elapsed=[Diagnostics.Stopwatch]::StartNew()
Start-Sleep -Seconds $Seconds
$measurements=@()
foreach($item in $sampleProcesses) {
 $item.Refresh()
 if($item.HasExited) { continue }
 $measurements+=[pscustomobject]@{ name=$item.ProcessName;pid=$item.Id;cpu_percent=[math]::Round(100*($item.CPU-$cpuBefore[$item.Id])/$elapsed.Elapsed.TotalSeconds/[Environment]::ProcessorCount,3);working_mb=[math]::Round($item.WorkingSet64/1MB,2);private_mb=[math]::Round($item.PrivateMemorySize64/1MB,2) }
}
$report=[pscustomobject]@{time=[DateTime]::Now.ToString('s');seconds=$elapsed.Elapsed.TotalSeconds;logical_processors=[Environment]::ProcessorCount;processes=$measurements;total_working_mb=($measurements | Measure-Object working_mb -Sum).Sum;total_cpu_percent=($measurements | Measure-Object cpu_percent -Sum).Sum}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding utf8
$report | ConvertTo-Json -Depth 5
