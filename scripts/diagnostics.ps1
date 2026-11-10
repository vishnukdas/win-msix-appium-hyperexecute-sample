# Prints the facts about the Windows runner that matter for MSIX + Appium automation.
$ErrorActionPreference = 'Continue'

function Section($name) { Write-Host "`n===== $name =====" }

Section 'OS'
$os = Get-CimInstance Win32_OperatingSystem
Write-Host "$($os.Caption) $($os.Version) build $($os.BuildNumber) $($os.OSArchitecture)"
Write-Host "PROCESSOR_ARCHITECTURE=$env:PROCESSOR_ARCHITECTURE"
Write-Host "User: $env:USERDOMAIN\$env:USERNAME"
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "Elevated admin: $admin"
Write-Host "Session: $((Get-Process -Id $PID).SessionId)  Interactive: $([Environment]::UserInteractive)"
Write-Host "Screen: $((Get-CimInstance Win32_VideoController | Select-Object -First 1).CurrentHorizontalResolution)x$((Get-CimInstance Win32_VideoController | Select-Object -First 1).CurrentVerticalResolution)"

Section 'Sideloading / Developer Mode'
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -ErrorAction SilentlyContinue |
  Select-Object AllowAllTrustedApps, AllowDevelopmentWithoutDevLicense | Format-List | Out-String | Write-Host
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx' -ErrorAction SilentlyContinue | Format-List | Out-String | Write-Host
Write-Host "Appx module: $([bool](Get-Command Add-AppxPackage -ErrorAction SilentlyContinue))"

Section 'Tools'
foreach ($t in 'node','npm','java','mvn','dotnet','git','ffmpeg','WinAppDriver','makeappx','signtool','winget','choco') {
  $c = Get-Command $t -ErrorAction SilentlyContinue
  Write-Host ("{0,-13} {1}" -f $t, $(if ($c) { $c.Source } else { '-' }))
}
node -v; npm -v; java -version 2>&1 | Select-Object -First 1; mvn -v 2>&1 | Select-Object -First 1
dotnet --list-sdks 2>&1
Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin' -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin\*\x64\makeappx.exe' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
Test-Path 'C:\Program Files\Windows Application Driver\WinAppDriver.exe'

Section 'Runtime frameworks'
Get-AppxPackage -Name 'Microsoft.VCLibs*' -ErrorAction SilentlyContinue | Select-Object Name, Version, Architecture | Format-Table | Out-String | Write-Host
Get-AppxPackage -Name 'Microsoft.WindowsAppRuntime*' -ErrorAction SilentlyContinue | Select-Object Name, Version | Format-Table | Out-String | Write-Host
Get-AppxPackage -Name 'Microsoft.UI.Xaml*' -ErrorAction SilentlyContinue | Select-Object Name, Version | Format-Table | Out-String | Write-Host

Section 'Disk / network'
Get-PSDrive C | Format-Table Used, Free | Out-String | Write-Host
try { $sw = [Diagnostics.Stopwatch]::StartNew(); Invoke-WebRequest https://registry.npmjs.org/appium -UseBasicParsing -TimeoutSec 20 | Out-Null; Write-Host "npm registry reachable ($($sw.ElapsedMilliseconds) ms)" } catch { Write-Host "npm registry: $_" }
