param(
  [string]$ProjectRoot = "$(Split-Path -Parent $PSScriptRoot)",
  [Parameter(Mandatory = $true)]
  [string]$TargetRoot
)

$ErrorActionPreference = "Stop"
$dist = Join-Path $ProjectRoot "dist\kb-guardian"
if (-not (Test-Path $dist)) {
  throw "找不到 dist\kb-guardian，請先執行 scripts\build.ps1"
}

$dirs = @(
  $TargetRoot,
  (Join-Path $TargetRoot "tools\kb-guardian"),
  (Join-Path $TargetRoot "KB\pages"),
  (Join-Path $TargetRoot "KB\journals"),
  (Join-Path $TargetRoot "KB\assets"),
  (Join-Path $TargetRoot "videos"),
  (Join-Path $TargetRoot "exports"),
  (Join-Path $TargetRoot "backups")
)

foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path $d | Out-Null }

Copy-Item -Recurse -Force "$dist\*" (Join-Path $TargetRoot "tools\kb-guardian")
Copy-Item -Force (Join-Path $ProjectRoot "START_HERE.bat") $TargetRoot
Copy-Item -Force (Join-Path $ProjectRoot "config.offline.ini") (Join-Path $TargetRoot "tools\kb-guardian\config.ini")

$readme = Join-Path $TargetRoot "README_使用說明.md"
$readmeContent = @'
# WorkStation 啟動說明

1. 雙擊 START_HERE.bat 啟動 KB-Guardian
2. 首次使用請確認以下工具已放入對應路徑：
   - tools/logseq-portable/Logseq.exe
   - tools/obs-portable/bin/64bit/obs64.exe
   - tools/pandoc/pandoc.exe
3. KB-Guardian 會自動建立 logs（於 tools/kb-guardian/logs/）與 backups
4. 備份檔在 backups/，匯出在 exports/
'@
$readmeContent | Set-Content -Encoding utf8 $readme

Write-Host "Deploy done: $TargetRoot"
