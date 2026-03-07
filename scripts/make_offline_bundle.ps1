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

# Compress-Archive 不包含空目錄，用 .gitkeep 佔位確保 ZIP 結構完整
foreach ($emptyDir in @("videos","exports","backups","KB/pages","KB/journals","KB/assets")) {
  $placeholder = Join-Path $bundleRoot "$emptyDir/.gitkeep"
  "" | Set-Content -Path $placeholder -Encoding UTF8
}
New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot $ReleaseDir) | Out-Null

Copy-Item -Recurse -Force "$ProjectRoot/dist/kb-guardian/*" $toolRoot
Copy-Item -Force "$ProjectRoot/START_HERE.bat" $bundleRoot
Copy-Item -Force "$ProjectRoot/config.offline.ini" (Join-Path $bundleRoot "tools/kb-guardian/config.ini")

# 複製可攜式工具（若本機已備妥）
foreach ($tool in @("logseq-portable", "obs-portable", "pandoc")) {
  $src = Join-Path $ProjectRoot "tools/$tool"
  if (Test-Path $src) {
    Write-Host "Copying tool: $tool ..."
    Copy-Item -Recurse -Force $src (Join-Path $bundleRoot "tools/$tool")
  } else {
    Write-Warning "Tool not found, skipping: $tool"
  }
}

$offlineReadme = Join-Path $bundleRoot "README_OFFLINE.md"
# 使用單引號 here-string（@'...'@）避免 PowerShell 將 `t 解析為 tab 字元
$readmeContent = @'
# KB-Guardian 離線使用包（全包含版）

## 使用步驟

1. 解壓此 ZIP 到任意位置（例如 D:\WorkStation\）
2. 雙擊 START_HERE.bat 啟動

全部工具已內附，目標機不需安裝任何軟體、不需連網。

## 內附工具版本

- Logseq portable (tools/logseq-portable/Logseq.exe)
- OBS Studio portable (tools/obs-portable/bin/64bit/obs64.exe)
- Pandoc (tools/pandoc/pandoc.exe)
- KB-Guardian (tools/kb-guardian/kb-guardian.exe) — 已內含 Python 執行環境

## 注意事項

- 若資料夾結構不同，請編輯 tools/kb-guardian/config.ini 調整路徑
- 備份、匯出、Log 會自動寫入同層資料夾（backups/、exports/、tools/kb-guardian/logs/）
- 請勿將此包直接放入中文或含空格的路徑（部分工具不支援）
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
