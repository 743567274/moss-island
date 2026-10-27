$ErrorActionPreference='Stop'
$userDataPath=Join-Path $env:APPDATA 'Godot/app_userdata/苔屿 · 桌面微观农场'
$farmIdentityBefore=(Get-Content -LiteralPath (Join-Path $userDataPath 'farm.json') -Raw | ConvertFrom-Json).payload.id
if(-not $farmIdentityBefore) { throw 'Existing farm identity missing' }
$hostProcess=Start-Process -FilePath (Join-Path $PWD 'build/MossIsland.exe') -ArgumentList '--mode=immersive' -WindowStyle Hidden -PassThru
function Read-SharedStatus([string]$path) {
 try {
  $stream=[IO.FileStream]::new($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
  $reader=[IO.StreamReader]::new($stream)
  try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
 } catch [IO.IOException] { return '' }
}
function Wait-FarmMode([string]$mode) {
 $processName=if($mode -eq 'immersive') {'MossImmersive'} else {'MossCompanion'}
 for($index=0;$index -lt 80;$index++) {
  $renderer=Get-Process -Name $processName -ErrorAction SilentlyContinue | Select-Object -First 1
  if($renderer) {
   $helpers=Get-CimInstance Win32_Process -Filter "Name = 'DesktopBridge.exe'"
   foreach($helper in $helpers) {
    if($helper.CommandLine -match (' '+$renderer.Id+' '+$hostProcess.Id+'$')) {
     $match=[regex]::Match($helper.CommandLine,'DesktopBridge.exe"?\s+(\d+)\s+"([^"]+)"')
     if($match.Success) {
      $statusPath=Join-Path $match.Groups[2].Value 'status'
      $status=if(Test-Path -LiteralPath $statusPath) {(Read-SharedStatus $statusPath)} else {''}
      if($status -match '\|(locked|companion)\s*$') {
       $writers=@(Get-Process -Name MossImmersive,MossCompanion -ErrorAction SilentlyContinue)
       if($writers.Count -ne 1) { throw 'More than one farm renderer' }
       return [pscustomobject]@{ Hwnd=$match.Groups[1].Value; Ipc=$match.Groups[2].Value; Pid=$renderer.Id }
      }
     }
    }
   }
  }
  Start-Sleep -Milliseconds 250
 }
 throw "Mode startup timeout: $mode"
}
function Wait-BridgeStatus($bridge,[string]$expected) {
 for($index=0;$index -lt 30;$index++) {
  if((Read-SharedStatus (Join-Path $bridge.Ipc 'status')).Trim().EndsWith('|'+$expected)) {return}
  Start-Sleep -Milliseconds 200
 }
 throw "Status timeout: $expected"
}
$first=Wait-FarmMode 'immersive'
$locked=(& ./build/DesktopBridge.exe --inspect $first.Hwnd | Out-String).Trim()
& ./build/MossIsland.exe --command=unlock
Wait-BridgeStatus $first 'unlocked'
$unlocked=(& ./build/DesktopBridge.exe --inspect $first.Hwnd | Out-String).Trim()
$lockedParent=[regex]::Match($locked,'Parent=(\d+)').Groups[1].Value
$unlockedParent=[regex]::Match($unlocked,'Parent=(\d+)').Groups[1].Value
if($lockedParent -eq '0' -or $unlockedParent -ne $lockedParent) { throw 'Unlock detached from desktop' }
Write-Output "RELEASE LOCKED: $locked"
Write-Output "RELEASE UNLOCKED: $unlocked"
& ./build/MossIsland.exe --command=lock
Wait-BridgeStatus $first 'locked'
& ./build/MossIsland.exe --command=companion
$second=Wait-FarmMode 'companion'
Write-Output ('RELEASE COMPANION: '+(& ./build/DesktopBridge.exe --inspect $second.Hwnd | Out-String).Trim())
& ./build/MossIsland.exe --command=immersive
$last=Wait-FarmMode 'immersive'
$farmIdentityAfter=(Get-Content -LiteralPath (Join-Path $userDataPath 'farm.json') -Raw | ConvertFrom-Json).payload.id
if($farmIdentityAfter -ne $farmIdentityBefore) { throw 'Farm identity changed' }
[pscustomobject]@{same_farm=$true;host_pid=$hostProcess.Id;renderer_pid=$last.Pid;locked_inspect=$locked;unlocked_inspect=$unlocked;mode='immersive';state='locked'} | ConvertTo-Json | Set-Content -LiteralPath build/release-lifecycle-v03.json -Encoding utf8
Write-Output 'RELEASE LIFECYCLE PASS: same farm, one writer, immersive → companion → immersive; left running as locked desktop wallpaper'
