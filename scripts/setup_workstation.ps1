param(
  [string]$ProjectRoot = "$(Split-Path -Parent $PSScriptRoot)",
  [string]$TargetRoot = "C:\WorkStation"
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

$readme = Join-Path $TargetRoot "README_使用說明.md"
@"
# WorkStation 啟動說明

1. 雙擊 START_HERE.bat
2. 第一次請先確認 tools/logseq-portable、tools/obs-portable、tools/pandoc 已放入
3. KB-Guardian 會自動建立 logs 與 backups
"@ | Set-Content -Encoding utf8 $readme

Write-Host "Deploy done: $TargetRoot"
