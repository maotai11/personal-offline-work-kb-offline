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
New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot $ReleaseDir) | Out-Null

foreach ($emptyDir in @("videos","exports","backups","KB/pages","KB/journals","KB/assets")) {
  $placeholder = Join-Path $bundleRoot "$emptyDir/.gitkeep"
  "" | Set-Content -Path $placeholder -Encoding UTF8
}

Copy-Item -Recurse -Force "$ProjectRoot/dist/kb-guardian/*" $toolRoot
Copy-Item -Force "$ProjectRoot/START_HERE.bat" $bundleRoot
Copy-Item -Force "$ProjectRoot/config.offline.ini" (Join-Path $bundleRoot "tools/kb-guardian/config.ini")
Copy-Item -Force "$ProjectRoot/scripts/README_OFFLINE_template.md" (Join-Path $bundleRoot "README_OFFLINE.md")

foreach ($tool in @("logseq-portable", "obs-portable", "pandoc")) {
  $src = Join-Path (Join-Path $ProjectRoot "tools") $tool
  $dst = Join-Path (Join-Path $bundleRoot "tools") $tool
  if (Test-Path $src) {
    Write-Host "Copying tool: $tool ..."
    Copy-Item -Recurse -Force $src $dst
  } else {
    Write-Warning "Tool not found, skipping: $tool"
  }
}

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
Write-Host "Compressing bundle (this may take a few minutes) ..."
Compress-Archive -Path "$bundleRoot/*" -DestinationPath $zipPath

Write-Host "bundle_dir=$bundleRoot"
Write-Host "bundle_zip=$zipPath"
