param(
  [string]$ProjectRoot = "$(Split-Path -Parent $PSScriptRoot)",
  [Parameter(Mandatory = $true)][string]$BatchId,
  [Parameter(Mandatory = $true)][string]$Summary,
  [string]$Status = "CONTINUE"
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

$checkpointDir = Join-Path $ProjectRoot "autopilot/checkpoints"
New-Item -ItemType Directory -Force -Path $checkpointDir | Out-Null

$gitAvailable = $false
$commit = ""
try {
  $inside = git rev-parse --is-inside-work-tree 2>$null
  if ($inside -eq "true") {
    $gitAvailable = $true
    $commit = (git rev-parse --short HEAD).Trim()
  }
} catch {
  $gitAvailable = $false
}

$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
$file = Join-Path $checkpointDir ("{0}_{1}.md" -f (Get-Date -Format "yyyyMMdd_HHmmss"), $BatchId)

$body = @"
# Batch Checkpoint $BatchId

- timestamp: $stamp
- status: $Status
- summary: $Summary
"@

if ($gitAvailable -and $commit) {
  $body += "`n- commit: $commit"
  $body += "`n- rollback: git checkout $commit"
}

$body += @"

[AUTOPILOT_STATUS]
status: $Status
next_prompt: continue highest-priority remaining tasks
summary: $Summary
[/AUTOPILOT_STATUS]
"@

Set-Content -Path $file -Encoding UTF8 -Value $body
Write-Host "checkpoint=$file"
