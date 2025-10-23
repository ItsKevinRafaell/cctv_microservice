param(
  [string]$VideoDevice = '',
  [ValidateSet('rtsp','rtmp')]
  [string]$Protocol = 'rtsp',
  [string]$RtspUrl = 'rtsp://127.0.0.1:8554/cam3',
  [string]$RtmpUrl = 'rtmp://127.0.0.1:1935/cam3',
  [int]$Fps = 25,                # set 0 to let device choose
  [string]$Size = '1280x720',    # set '' or 'auto' to let device choose
  [int]$OutWidth = 640,
  [switch]$NoScale,
  [switch]$SkipDocker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ComposeInfo {
  $cmd = Get-Command docker-compose -ErrorAction SilentlyContinue
  if ($cmd) { return [pscustomobject]@{ Exe = $cmd.Source; BaseArgs = @() } }
  try {
    $null = & docker compose version 2>$null
    if ($LASTEXITCODE -eq 0) { return [pscustomobject]@{ Exe = 'docker'; BaseArgs = @('compose') } }
  } catch {}
  throw 'Neither "docker-compose" nor "docker compose" found in PATH.'
}

function Get-FFmpegPath {
  $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $localDir = Join-Path $PSScriptRoot 'bin/ffmpeg'
  $possible = @(
    (Join-Path $localDir 'bin/ffmpeg.exe'),
    (Join-Path $localDir 'ffmpeg.exe')
  )
  foreach ($p in $possible) { if (Test-Path $p) { return (Resolve-Path $p).Path } }

  Write-Host '[setup] ffmpeg not found, downloading portable build...' -ForegroundColor Yellow
  New-Item -ItemType Directory -Force -Path $localDir | Out-Null
  $zipUrl = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
  $zipPath = Join-Path $localDir 'ffmpeg-release-essentials.zip'
  Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
  Expand-Archive -Path $zipPath -DestinationPath $localDir -Force
  Remove-Item $zipPath -Force
  $exe = Get-ChildItem -Path $localDir -Recurse -Filter ffmpeg.exe | Select-Object -First 1
  if (-not $exe) { throw 'Failed to locate ffmpeg.exe in downloaded archive.' }
  return $exe.FullName
}

function Ensure-Mediamtx {
  # Ensure mediamtx container is up (using repo root docker-compose.yml)
  $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
  Write-Host "[setup] Ensuring mediamtx is running (compose up -d mediamtx)" -ForegroundColor Cyan
  $compose = Get-ComposeInfo
  & $compose.Exe @($compose.BaseArgs + @('-f', (Join-Path $repoRoot 'docker-compose.yml'), 'up', '-d', 'mediamtx')) | Out-Null
}

function Get-DefaultVideoDevice([string]$ffmpegPath) {
  $out = & $ffmpegPath -hide_banner -f dshow -list_devices true -i dummy 2>&1
  $lines = $out -split "`r?`n"
  $inVideo = $false
  foreach ($ln in $lines) {
    if ($ln -match 'DirectShow video devices') { $inVideo = $true; continue }
    if ($inVideo -and $ln -match 'DirectShow audio devices') { break }
    if ($inVideo) {
      if ($ln -match '"([^"]+)"') {
        return $Matches[1]
      }
    }
  }
  return ''
}

try {
  $targetHost = $null
  if ([Uri]::TryCreate(($Protocol -eq 'rtmp') ? $RtmpUrl : $RtspUrl, [System.UriKind]::Absolute, [ref]$targetHost)) {
    $targetHost = $targetHost.Host
  } else {
    $targetHost = ''
  }

  $manageDocker = -not $SkipDocker.IsPresent -and (
      [string]::IsNullOrWhiteSpace($targetHost) -or
      $targetHost -eq 'localhost' -or
      $targetHost -eq '127.0.0.1'
    )

  if ($manageDocker) {
    Ensure-Mediamtx
    # Stop dummy test publisher if running to avoid path conflicts on 'cam3'
    try {
      $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
      $compose = Get-ComposeInfo
      & $compose.Exe @($compose.BaseArgs + @('-f', (Join-Path $repoRoot 'docker-compose.yml'), 'stop', 'test_publisher_cam3')) | Out-Null
    } catch {}
  } else {
    Write-Host "[info] SkipDocker aktif atau target host bukan lokal ('$targetHost'); melewati orchestration Docker." -ForegroundColor Yellow
  }
  $ffmpeg = Get-FFmpegPath
  Write-Host "[ok] Using ffmpeg: $ffmpeg" -ForegroundColor Green

  if (-not $VideoDevice) {
    $VideoDevice = Get-DefaultVideoDevice -ffmpegPath $ffmpeg
    if (-not $VideoDevice) {
      throw 'No DirectShow video device found. Plug in a webcam or specify -VideoDevice "Your Camera Name".'
    }
    Write-Host "[detected] Video device: '$VideoDevice'" -ForegroundColor Green
  } else {
    Write-Host "[cfg] Using provided device: '$VideoDevice'" -ForegroundColor Green
  }

  $vf = @()
  if (-not $NoScale) { $vf = @('-vf', "scale=$($OutWidth):-2") }

  $inArgs = @('-loglevel','info','-f','dshow','-rtbufsize','100M')
  if ($Fps -gt 0) { $inArgs += @('-framerate',"$Fps") }
  if ([string]::IsNullOrWhiteSpace($Size) -or $Size -eq 'auto') { }
  else { $inArgs += @('-video_size',"$Size") }

  # Quote the device for ffmpeg dshow input. In PowerShell, escape quotes with backticks.
  $dshowInput = "video=`"$VideoDevice`""

  # Encoding options
  $gop = if ($Fps -gt 0) { [int]($Fps*2) } else { 50 }
  $enc = @(
    '-c:v','libx264',
    '-preset','veryfast',
    '-tune','zerolatency',
    '-pix_fmt','yuv420p',
    '-profile:v','main',
    '-g',"$gop",
    '-x264-params',"scenecut=0:open_gop=0:keyint=$gop"
  )
  if ($Fps -gt 0) { $enc += @('-r',"$Fps") }

  # Output (RTSP or RTMP)
  if ($Protocol -eq 'rtmp') {
    $out = @('-f','flv', $RtmpUrl)
    $dstUrl = $RtmpUrl
  } else {
    $out = @('-f','rtsp','-rtsp_transport','tcp','-muxdelay','0','-muxpreload','0', $RtspUrl)
    $dstUrl = $RtspUrl
  }

  $args = $inArgs + @('-i', $dshowInput) + $vf + $enc + $out

  Write-Host "[start] Streaming webcam to $dstUrl (press Ctrl+C to stop)" -ForegroundColor Cyan
  Write-Host "        Device='$VideoDevice' FPS=$Fps Size=$Size OutWidth=$OutWidth"
  & $ffmpeg @args
}
catch {
  Write-Host ("[error] " + $_.Exception.Message) -ForegroundColor Red
  exit 1
}
