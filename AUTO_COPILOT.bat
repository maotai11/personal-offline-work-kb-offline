@echo off
setlocal
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File ".\scripts\run_autocopilot.ps1" -ProjectRoot "%~dp0"
echo.
echo Auto-copilot finished.
pause
