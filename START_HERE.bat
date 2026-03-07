@echo off
chcp 65001 >nul
cd /d "%~dp0"

if exist ".\kb-guardian.exe" (
  start "" ".\kb-guardian.exe"
) else if exist ".\tools\kb-guardian\kb-guardian.exe" (
  start "" ".\tools\kb-guardian\kb-guardian.exe"
) else (
  echo.
  echo [ERROR] kb-guardian.exe not found.
  echo Please check one of the following paths exists:
  echo   .\kb-guardian.exe
  echo   .\tools\kb-guardian\kb-guardian.exe
  echo.
  pause
)
