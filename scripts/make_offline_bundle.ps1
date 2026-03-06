param(
  [string]$ProjectRoot = "$(Split-Path -Parent $PSScriptRoot)",
  [string]$ReleaseDir  = "release",
  [switch]$Rebuild,
  [switch]$SkipToolDownload   # 若工具已預先放好則略過下載
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

$PANDOC_VERSION = "3.6.4"
$LOGSEQ_VERSION = "0.10.9"
$OBS_VERSION    = "31.0.3"

# ── 1. 建置 KB-Guardian 執行檔 ──────────────────────────────────────
if ($Rebuild -or -not (Test-Path "dist\kb-guardian\kb-guardian.exe")) {
  & "$ProjectRoot\scripts\build.ps1" -ProjectRoot $ProjectRoot
}

$stamp      = Get-Date -Format "yyyyMMdd_HHmmss"
$bundleName = "kb-guardian-offline-$stamp"
$bundleRoot = Join-Path $ProjectRoot "$ReleaseDir\$bundleName"

if (Test-Path $bundleRoot) { Remove-Item -Recurse -Force $bundleRoot }

# ── 2. 下載工具（若未跳過）───────────────────────────────────────────
$dlDir = Join-Path $ProjectRoot "_tool_downloads"
New-Item -ItemType Directory -Force $dlDir | Out-Null

function Download-If-Missing {
  param($Name, $Url, $Dest)
  if (Test-Path $Dest) {
    Write-Host "  ✓ $Name 已存在，略過下載" -ForegroundColor DarkGray
  } else {
    Write-Host "  ↓ 下載 $Name ..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $Url -OutFile $Dest
  }
}

if (-not $SkipToolDownload) {
  Write-Host "[下載工具]" -ForegroundColor Cyan
  Download-If-Missing "Pandoc $PANDOC_VERSION" `
    "https://github.com/jgm/pandoc/releases/download/$PANDOC_VERSION/pandoc-$PANDOC_VERSION-windows-x86_64.zip" `
    "$dlDir\pandoc.zip"
  Download-If-Missing "Logseq $LOGSEQ_VERSION" `
    "https://github.com/logseq/logseq/releases/download/$LOGSEQ_VERSION/Logseq-win-x64-$LOGSEQ_VERSION.zip" `
    "$dlDir\logseq.zip"
  Download-If-Missing "OBS $OBS_VERSION" `
    "https://github.com/obsproject/obs-studio/releases/download/$OBS_VERSION/OBS-Studio-$OBS_VERSION-Windows.zip" `
    "$dlDir\obs.zip"
}

# ── 3. 組裝目錄結構 ─────────────────────────────────────────────────
# 最終結構（解壓後 config.ini 相對路徑 ..\tools\... 即可對應）：
#   release\kb-guardian-offline-<ts>\         ← KB-Guardian 執行檔
#   release\kb-guardian-offline-<ts>\..\tools\ ← 三個工具

$toolsRoot = "$bundleRoot\..\tools"
New-Item -ItemType Directory -Force "$toolsRoot\pandoc"           | Out-Null
New-Item -ItemType Directory -Force "$toolsRoot\logseq-portable"  | Out-Null
New-Item -ItemType Directory -Force "$toolsRoot\obs-portable"     | Out-Null

# 建立 KB 所需資料夾
foreach ($d in @("KB\pages","KB\journals","KB\assets","videos","exports","backups","logs")) {
  New-Item -ItemType Directory -Force (Join-Path $bundleRoot $d) | Out-Null
}

# 複製 KB-Guardian 本體
New-Item -ItemType Directory -Force $bundleRoot | Out-Null
Copy-Item -Recurse -Force "dist\kb-guardian\*" $bundleRoot
Copy-Item -Force "START_HERE.bat" $bundleRoot -ErrorAction SilentlyContinue

Write-Host "[解壓工具]" -ForegroundColor Cyan

# Pandoc → tools\pandoc\pandoc.exe
Write-Host "  Pandoc..."
Expand-Archive "$dlDir\pandoc.zip" -DestinationPath "$env:TEMP\_pandoc_tmp" -Force
Copy-Item "$env:TEMP\_pandoc_tmp\pandoc-$PANDOC_VERSION\pandoc.exe" "$toolsRoot\pandoc\"
Remove-Item "$env:TEMP\_pandoc_tmp" -Recurse -Force

# Logseq → tools\logseq-portable\
Write-Host "  Logseq..."
Expand-Archive "$dlDir\logseq.zip" -DestinationPath "$toolsRoot\logseq-portable" -Force

# OBS → tools\obs-portable\
Write-Host "  OBS..."
Expand-Archive "$dlDir\obs.zip" -DestinationPath "$toolsRoot\obs-portable" -Force

# ── 4. README ────────────────────────────────────────────────────────
@"
# KB-Guardian 完整離線包

## 快速啟動
1. 解壓縮後，直接執行 `kb-guardian.exe`
2. 如需自訂工具路徑，編輯 `_internal\config.ini` 後重新啟動

## 已內建工具
| 工具 | 版本 | 路徑 |
|------|------|------|
| Logseq | $LOGSEQ_VERSION | `..\tools\logseq-portable\Logseq.exe` |
| OBS Studio | $OBS_VERSION | `..\tools\obs-portable\bin\64bit\obs64.exe` |
| Pandoc | $PANDOC_VERSION | `..\tools\pandoc\pandoc.exe` |

## 目錄說明
- `KB\`       — 知識庫根目錄（首次啟動後自動建立 pages / journals / assets）
- `backups\`  — 自動備份存放位置
- `exports\`  — SOP 匯出存放位置
- `logs\`     — 應用程式日誌
"@ | Set-Content -Encoding UTF8 (Join-Path $bundleRoot "README_OFFLINE.md")

# ── 5. SHA256 manifest ───────────────────────────────────────────────
$manifest = Join-Path $bundleRoot "MANIFEST_SHA256.txt"
Get-ChildItem -File -Recurse $bundleRoot, $toolsRoot |
  Sort-Object FullName |
  ForEach-Object {
    $hash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash
    "$hash  $($_.FullName.Replace($ProjectRoot + '\', ''))"
  } | Set-Content -Encoding UTF8 $manifest

# ── 6. 壓縮 ─────────────────────────────────────────────────────────
Write-Host "[壓縮]" -ForegroundColor Cyan
New-Item -ItemType Directory -Force (Join-Path $ProjectRoot $ReleaseDir) | Out-Null
$zipPath = Join-Path $ProjectRoot "$ReleaseDir\$bundleName.zip"
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }

# 同時壓入 kb-guardian 執行檔目錄 和 tools 目錄
Compress-Archive -Path $bundleRoot, $toolsRoot -DestinationPath $zipPath

$sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
$sha256 = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLower()

Write-Host ""
Write-Host "=== 完成 ===" -ForegroundColor Green
Write-Host "  ZIP    : $zipPath  ($sizeMB MB)"
Write-Host "  SHA256 : $sha256"

"bundle_dir=$bundleRoot"
"bundle_zip=$zipPath"
