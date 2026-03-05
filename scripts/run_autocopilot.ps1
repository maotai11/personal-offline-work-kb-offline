param(
  [string]$ProjectRoot = "$(Split-Path -Parent $PSScriptRoot)"
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

Write-Host "[auto-copilot] batch 1: smoke/build"
& "$ProjectRoot/scripts/build.ps1" -ProjectRoot $ProjectRoot -Clean
& "$ProjectRoot/scripts/create_checkpoint.ps1" -ProjectRoot $ProjectRoot -BatchId "AUTO_001" -Summary "Build and smoke test finished" -Status "CONTINUE"

Write-Host "[auto-copilot] batch 2: offline bundle"
& "$ProjectRoot/scripts/make_offline_bundle.ps1" -ProjectRoot $ProjectRoot
& "$ProjectRoot/scripts/create_checkpoint.ps1" -ProjectRoot $ProjectRoot -BatchId "AUTO_002" -Summary "Offline bundle generated in release/" -Status "DONE"

Write-Host "[auto-copilot] completed"
