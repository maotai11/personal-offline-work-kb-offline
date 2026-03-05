param(
  [string]$ProjectRoot = "$(Split-Path -Parent $PSScriptRoot)",
  [string]$ReleaseDir = "release",
  [switch]$Rebuild
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

if ($Rebuild -or -not (Test-Path "dist/kb-guardian/kb-guardian.exe")) {
  & "$ProjectRoot/scripts/build.ps1" -ProjectRoot $ProjectRoot
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$bundleName = "kb-guardian-offline-$stamp"
$bundleRoot = Join-Path $ProjectRoot "$ReleaseDir/$bundleName"
$toolRoot = Join-Path $bundleRoot "tools/kb-guardian"

if (Test-Path $bundleRoot) {
  Remove-Item -Recurse -Force $bundleRoot
}

New-Item -ItemType Directory -Force -Path $toolRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $bundleRoot "KB/pages") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $bundleRoot "KB/journals") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $bundleRoot "KB/assets") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $bundleRoot "videos") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $bundleRoot "exports") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $bundleRoot "backups") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $bundleRoot "logs") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot $ReleaseDir) | Out-Null

Copy-Item -Recurse -Force "$ProjectRoot/dist/kb-guardian/*" $toolRoot
Copy-Item -Force "$ProjectRoot/START_HERE.bat" $bundleRoot
Copy-Item -Force "$ProjectRoot/config.ini.example" (Join-Path $bundleRoot "tools/kb-guardian/config.ini")

$offlineReadme = Join-Path $bundleRoot "README_OFFLINE.md"
@"
# KB-Guardian Offline Bundle

## Usage
1. Place your portable tools under:
   - `tools/logseq-portable/Logseq.exe`
   - `tools/obs-portable/bin/64bit/obs64.exe`
   - `tools/pandoc/pandoc.exe`
2. Double-click `START_HERE.bat`.
3. Backups, exports, and logs are written to sibling folders in this bundle.

## Notes
- This package is self-contained for Python runtime (`kb-guardian.exe` included).
- Edit `tools/kb-guardian/config.ini` when your folder layout differs.
"@ | Set-Content -Encoding UTF8 $offlineReadme

$manifest = Join-Path $bundleRoot "MANIFEST_SHA256.txt"
Get-ChildItem -File -Recurse $bundleRoot |
  Sort-Object FullName |
  ForEach-Object {
    $hash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash
    "$hash  $($_.FullName.Substring($bundleRoot.Length + 1))"
  } | Set-Content -Encoding UTF8 $manifest

$zipPath = Join-Path $ProjectRoot "$ReleaseDir/$bundleName.zip"
if (Test-Path $zipPath) {
  Remove-Item -Force $zipPath
}
Compress-Archive -Path "$bundleRoot/*" -DestinationPath $zipPath

Write-Host "bundle_dir=$bundleRoot"
Write-Host "bundle_zip=$zipPath"
