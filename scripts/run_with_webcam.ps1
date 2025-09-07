param(
  [string]$VideoDevice = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ComposeInfo {
  # Prefer docker-compose (v1) if present; else use docker compose (v2)
  $cmd = Get-Command docker-compose -ErrorAction SilentlyContinue
  if ($cmd) { return [pscustomobject]@{ Exe = $cmd.Source; BaseArgs = @() } }
  try {
    $null = & docker compose version 2>$null
    if ($LASTEXITCODE -eq 0) { return [pscustomobject]@{ Exe = 'docker'; BaseArgs = @('compose') } }
  } catch {}
  throw 'Neither "docker-compose" nor "docker compose" found in PATH.'
}

function Wait-Port($HostName, $Port, $TimeoutSec = 60) {
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    try {
      $client = New-Object System.Net.Sockets.TcpClient
      $iar = $client.BeginConnect($HostName, $Port, $null, $null)
      if ($iar.AsyncWaitHandle.WaitOne(1000)) { $client.EndConnect($iar); $client.Close(); return $true }
      $client.Close()
    } catch {}
  }
  return $false
}

try {
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
  $composeFile = Join-Path $repoRoot 'docker-compose.yml'
  if (-not (Test-Path $composeFile)) { throw "docker-compose.yml not found at $composeFile" }

  $compose = Get-ComposeInfo
  Write-Host "[up] Starting Docker services (this may take a while)..." -ForegroundColor Cyan
  & $compose.Exe @($compose.BaseArgs + @('-f', $composeFile, 'up', '-d'))

  # Avoid conflict on cam3: stop dummy publisher if it got started
  try { & $compose.Exe @($compose.BaseArgs + @('-f', $composeFile, 'stop', 'test_publisher_cam3')) | Out-Null } catch {}

  # Ensure MediaMTX is ready (RTSP & HLS)
  Write-Host "[wait] Waiting MediaMTX ports 8554 (RTSP) and 8888 (HLS)..." -ForegroundColor Cyan
  if (-not (Wait-Port '127.0.0.1' 8554 60)) { throw 'Timeout waiting for RTSP 8554' }
  if (-not (Wait-Port '127.0.0.1' 8888 60)) { throw 'Timeout waiting for HLS 8888' }

  # Start webcam → cam3 stream in a new PowerShell
  $streamScript = Join-Path $repoRoot 'cctv-camera/start_cam3_stream.ps1'
  if (-not (Test-Path $streamScript)) { throw "Stream script not found: $streamScript" }
  $args = @('-ExecutionPolicy','Bypass','-File', $streamScript)
  if ($VideoDevice) { $args += @('-VideoDevice', $VideoDevice) }

  Write-Host "[start] Launching webcam stream to cam3..." -ForegroundColor Green
  Start-Process -FilePath 'powershell.exe' -ArgumentList $args -WindowStyle Normal | Out-Null

  Write-Host "[ok] Services are up. Webcam stream started in a new window." -ForegroundColor Green
  Write-Host "     HLS: http://127.0.0.1:8888/cam3/index.m3u8" -ForegroundColor Green
}
catch {
  Write-Host ("[error] " + $_.Exception.Message) -ForegroundColor Red
  exit 1
}
