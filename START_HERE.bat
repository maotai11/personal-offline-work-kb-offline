@echo off
chcp 65001 >nul
echo 正在啟動 KB-Guardian...
cd /d "%~dp0"
if exist ".\kb-guardian.exe" (
  start "" ".\kb-guardian.exe"
) else (
  python -m kb_guardian.main
)
