$ErrorActionPreference = 'Stop'
$compilerPath = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compilerPath /nologo /target:exe /platform:x64 /optimize+ /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:Accessibility.dll "/out:$PSScriptRoot\DesktopBridge.exe" "$PSScriptRoot\DesktopBridge.cs"
if ($LASTEXITCODE -ne 0) { throw 'DesktopBridge build failed' }
& $compilerPath /nologo /target:winexe /platform:x64 /optimize+ /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Device.dll /reference:System.Web.Extensions.dll "/out:$PSScriptRoot\TrayHost.exe" "$PSScriptRoot\TrayHost.cs"
if ($LASTEXITCODE -ne 0) { throw 'TrayHost build failed' }
