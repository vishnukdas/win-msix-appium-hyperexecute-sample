<#
  Installs an MSIX for testing and writes its Application User Model ID (AUMID) for the tests.

  -Source   .zip (MSIX + .cer + Dependencies\), .msix, or an http(s) URL to either
  -EnvFile  where to write APP_ID=<PackageFamilyName>!<AppId> (default build\installed-app.env)

  Sideloading prerequisites handled here:
    1. Trust the signing certificate (LocalMachine\TrustedPeople, needs admin).
    2. Install framework dependencies (VCLibs, Windows App Runtime) before the app.
    3. Add-AppxPackage, replacing any previous install of the same package.
#>
param(
  [Parameter(Mandatory = $true)][string]$Source,
  [string]$EnvFile = 'build\installed-app.env'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with the progress bar on

$work = Join-Path (Get-Location) 'build\msix'
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $work | Out-Null

if ($Source -match '^https?://') {
  $file = Join-Path $work ([IO.Path]::GetFileName(([Uri]$Source).AbsolutePath))
  Write-Host "Downloading $Source"
  $sw = [Diagnostics.Stopwatch]::StartNew()
  Invoke-WebRequest $Source -OutFile $file -UseBasicParsing
  Write-Host ("Downloaded {0:N1} MB in {1:N1}s" -f ((Get-Item $file).Length / 1MB), $sw.Elapsed.TotalSeconds)
  $Source = $file
}

if ($Source -like '*.zip') {
  Expand-Archive $Source -DestinationPath $work -Force
  $msix = Get-ChildItem $work -Recurse -Include *.msix, *.msixbundle | Where-Object { $_.FullName -notmatch '\\Dependencies\\' } | Select-Object -First 1
} else {
  $msix = Get-Item $Source
}
if (-not $msix) { throw "No .msix found in $Source" }

# 1. Trust the signing certificate. Use the .cer shipped next to the package if there is one,
#    otherwise read the certificate straight out of the package signature.
$cer = Get-ChildItem $msix.DirectoryName -Filter *.cer | Select-Object -First 1
if ($cer) {
  Import-Certificate -FilePath $cer.FullName -CertStoreLocation Cert:\LocalMachine\TrustedPeople | Out-Null
  Write-Host "Trusted certificate $($cer.Name)"
} else {
  $signer = (Get-AuthenticodeSignature $msix.FullName).SignerCertificate
  if ($signer) {
    $tmp = Join-Path $work 'signer.cer'
    [IO.File]::WriteAllBytes($tmp, $signer.Export('Cert'))
    Import-Certificate -FilePath $tmp -CertStoreLocation Cert:\LocalMachine\TrustedPeople | Out-Null
    Write-Host "Trusted signer $($signer.Subject)"
  }
}

# 2. Framework dependencies. Already-installed (or newer) frameworks are skipped by Windows.
$deps = Get-ChildItem $msix.DirectoryName -Recurse -Include *.appx, *.msix |
  Where-Object { $_.FullName -match '\\Dependencies\\' -and $_.FullName -notmatch '\\(x86|arm|arm64)\\' }
foreach ($d in $deps) {
  try {
    Add-AppxPackage -Path $d.FullName -ErrorAction Stop
    Write-Host "Installed dependency $($d.Name)"
  } catch {
    Write-Host "Dependency $($d.Name) skipped: $($_.Exception.Message.Split([Environment]::NewLine)[0])"
  }
}

# 3. The app itself.
$sw = [Diagnostics.Stopwatch]::StartNew()
Add-AppxPackage -Path $msix.FullName -ForceApplicationShutdown -ForceUpdateFromAnyVersion
Write-Host ("Installed {0} in {1:N1}s" -f $msix.Name, $sw.Elapsed.TotalSeconds)

# Resolve the AUMID from the installed package's manifest.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($msix.FullName)
try {
  $reader = New-Object IO.StreamReader($zip.GetEntry('AppxManifest.xml').Open())
  [xml]$manifest = $reader.ReadToEnd()
  $reader.Close()
} finally { $zip.Dispose() }
$name = $manifest.Package.Identity.Name
$appId = @($manifest.Package.Applications.Application)[0].Id
$pkg = Get-AppxPackage -Name $name | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pkg) { throw "Package $name is not installed" }
$aumid = "$($pkg.PackageFamilyName)!$appId"

New-Item -ItemType Directory -Force (Split-Path $EnvFile) | Out-Null
Set-Content -Path $EnvFile -Encoding ascii -Value @(
  "APP_ID=$aumid",
  "PACKAGE_NAME=$name",
  "PACKAGE_VERSION=$($pkg.Version)",
  "INSTALL_LOCATION=$($pkg.InstallLocation -replace '\\', '\\')"
)
Write-Host "APP_ID=$aumid"
Write-Host "Wrote $EnvFile"
