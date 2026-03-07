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
# logs 由 kb-guardian.exe 啟動時自動建立於 tools/kb-guardian/logs/，不在根層建立
New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot $ReleaseDir) | Out-Null

Copy-Item -Recurse -Force "$ProjectRoot/dist/kb-guardian/*" $toolRoot
Copy-Item -Force "$ProjectRoot/START_HERE.bat" $bundleRoot
Copy-Item -Force "$ProjectRoot/config.offline.ini" (Join-Path $bundleRoot "tools/kb-guardian/config.ini")

$offlineReadme = Join-Path $bundleRoot "README_OFFLINE.md"
# 使用單引號 here-string（@'...'@）避免 PowerShell 將 `t 解析為 tab 字元
$readmeContent = @'
# KB-Guardian 離線使用包

## 使用步驟

1. 將可攜式工具解壓放置於以下路徑：
   - tools/logseq-portable/Logseq.exe
   - tools/obs-portable/bin/64bit/obs64.exe
   - tools/pandoc/pandoc.exe

2. 雙擊 START_HERE.bat 啟動

3. 備份、匯出、Log 會自動寫入同層資料夾（backups/、exports/、tools/kb-guardian/logs/）

## 注意事項

- kb-guardian.exe 已內含 Python 執行環境，目標機不需安裝 Python
- 若資料夾結構不同，請編輯 tools/kb-guardian/config.ini 調整路徑
- 請使用「可攜式（portable）zip 版」的 Logseq / OBS，安裝版無法直接放入 tools/

## 工具下載（需在有網路的機器預先下載）

- Logseq portable zip：GitHub > logseq/logseq > Releases > 下載 .zip（非 .exe 安裝版）
- OBS portable zip：GitHub > obsproject/obs-studio > Releases > 下載 Windows ZIP（非 Installer）
- Pandoc zip：GitHub > jgm/pandoc > Releases > 下載 windows-x86_64.zip
'@
$readmeContent | Set-Content -Encoding UTF8 $offlineReadme

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
