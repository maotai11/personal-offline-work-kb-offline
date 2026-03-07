param(
  [string]$ProjectRoot = "$(Split-Path -Parent $PSScriptRoot)",
  [switch]$Clean
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

if ($Clean -and (Test-Path "build")) { Remove-Item -Recurse -Force "build" }
if ($Clean -and (Test-Path "dist")) { Remove-Item -Recurse -Force "dist" }

if (-not (Test-Path ".venv")) {
  python -m venv .venv
}

& .\.venv\Scripts\python -m pip install --upgrade pip
& .\.venv\Scripts\python -m pip install -r requirements.txt pyinstaller

& .\.venv\Scripts\python -m py_compile .\kb_guardian\main.py
& .\.venv\Scripts\python -m kb_guardian.smoke

& .\.venv\Scripts\python .\scripts\create_icon.py

& .\.venv\Scripts\pyinstaller --noconfirm kb-guardian.spec

Write-Host "Build done: $ProjectRoot\dist\kb-guardian"
