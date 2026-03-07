@echo off
chcp 65001 >nul
echo 正在啟動 KB-Guardian...
cd /d "%~dp0"
if exist ".\kb-guardian.exe" (
  start "" ".\kb-guardian.exe"
) else if exist ".\tools\kb-guardian\kb-guardian.exe" (
  start "" ".\tools\kb-guardian\kb-guardian.exe"
) else (
  echo.
  echo [錯誤] 找不到 kb-guardian.exe！
  echo 請確認以下路徑之一存在：
  echo   .\kb-guardian.exe
  echo   .\tools\kb-guardian\kb-guardian.exe
  echo.
  pause
)
