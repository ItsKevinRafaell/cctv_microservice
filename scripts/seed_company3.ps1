Param(
  [string]$ApiBase = "http://127.0.0.1:8080",
  [int]$CompanyId = 3,
  [string]$SuperEmail = "superadmin@example.com",
  [string]$SuperPassword = "ChangeMe123!",
  [string]$NewUserEmail = "company3admin@example.com",
  [string]$NewUserPassword = "Passw0rd123!",
  [string]$StreamKey = "cam3",
  [string]$ClipPath = "/video-clips/cam3/clip_001.mp4",
  [string]$OptionalFcmToken = ""
)

Write-Host "[seed] API_BASE=$ApiBase, COMPANY_ID=$CompanyId" -ForegroundColor Cyan

function Invoke-Json {
  param([string]$Method, [string]$Url, [hashtable]$Headers, [object]$Body)
  try {
    if ($Body -ne $null -and ($Method -eq 'POST' -or $Method -eq 'PUT')) {
      return Invoke-RestMethod -Uri $Url -Method $Method -Headers $Headers -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 6)
    } else {
      return Invoke-RestMethod -Uri $Url -Method $Method -Headers $Headers
    }
  } catch {
    Write-Warning "[$Method $Url] $($_.Exception.Message)"
    if ($_.Exception.Response) {
      try { $sr = New-Object IO.StreamReader $_.Exception.Response.GetResponseStream(); $txt = $sr.ReadToEnd(); Write-Warning $txt } catch {}
    }
    throw
  }
}

# 1) Login as superadmin
Write-Host "[seed] Login as superadmin..." -ForegroundColor Yellow
$login = Invoke-RestMethod -Uri "$ApiBase/api/login" -Method POST -ContentType 'application/json' -Body ( @{ email=$SuperEmail; password=$SuperPassword } | ConvertTo-Json )
$token = $login.token
if (-not $token) { throw "Login failed: missing token" }
$H = @{ Authorization = "Bearer $token" }
Write-Host "[seed] OK" -ForegroundColor Green

# 2) Ensure a user in company=CompanyId exists (role company_admin)
Write-Host "[seed] Create or ensure user $NewUserEmail in company $CompanyId..." -ForegroundColor Yellow
try {
  Invoke-Json -Method POST -Url "$ApiBase/api/register" -Headers $H -Body @{ email=$NewUserEmail; password=$NewUserPassword; company_id=$CompanyId; role='company_admin' } | Out-Null
  Write-Host "[seed] User created" -ForegroundColor Green
} catch {
  Write-Host "[seed] Skip create (maybe exists)" -ForegroundColor DarkYellow
}

# Optional: login as that user (needed if we want to upsert FCM token via API)
$uToken = $null
try {
  $ulogin = Invoke-RestMethod -Uri "$ApiBase/api/login" -Method POST -ContentType 'application/json' -Body ( @{ email=$NewUserEmail; password=$NewUserPassword } | ConvertTo-Json )
  $uToken = $ulogin.token
} catch {}

if ($OptionalFcmToken -and $uToken) {
  Write-Host "[seed] Upsert FCM token for $NewUserEmail" -ForegroundColor Yellow
  $uH = @{ Authorization = "Bearer $uToken" }
  Invoke-Json -Method POST -Url "$ApiBase/api/users/fcm-token" -Headers $uH -Body @{ fcm_token=$OptionalFcmToken } | Out-Null
  Write-Host "[seed] FCM token saved" -ForegroundColor Green
} elseif ($OptionalFcmToken -and -not $uToken) {
  Write-Host "[seed] WARN: cannot upsert FCM token (user login failed)" -ForegroundColor DarkYellow
}

# 3) Create camera in company CompanyId with provided StreamKey
Write-Host "[seed] Create camera stream_key=$StreamKey for company=$CompanyId..." -ForegroundColor Yellow
$camId = $null
try {
  $cres = Invoke-Json -Method POST -Url "$ApiBase/api/cameras" -Headers $H -Body @{ name="Demo Cam $StreamKey"; location="Demo"; stream_key=$StreamKey; company_id=$CompanyId }
  $camId = $cres.camera_id
  if (-not $camId) { throw "missing camera_id in response" }
  Write-Host "[seed] Camera created: id=$camId" -ForegroundColor Green
} catch {
  Write-Host "[seed] Maybe exists, try list..." -ForegroundColor DarkYellow
}

if (-not $camId) {
  $list = Invoke-Json -Method GET -Url "$ApiBase/api/cameras?company_id=$CompanyId" -Headers $H
  $found = $list | Where-Object { $_.stream_key -eq $StreamKey }
  if ($found) { $camId = $found.id; Write-Host "[seed] Found camera: id=$camId" -ForegroundColor Green }
}
if (-not $camId) { throw "Failed to obtain camera id for $StreamKey" }

# 4) Report an anomaly (clip optional)
Write-Host "[seed] Report anomaly for camera_id=$camId..." -ForegroundColor Yellow
$body = @{ camera_id = [int]$camId; anomaly_type = 'intrusion'; confidence = 0.9; reported_at = (Get-Date).ToUniversalTime().ToString('o') }
if ($ClipPath) { $body.video_clip_url = $ClipPath }
Invoke-Json -Method POST -Url "$ApiBase/api/report-anomaly" -Headers @{} -Body $body | Out-Null
Write-Host "[seed] Anomaly sent" -ForegroundColor Green

Write-Host ""; Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1) On the app, login as: $NewUserEmail / $NewUserPassword (company $CompanyId)." -ForegroundColor Gray
Write-Host "   This registers FCM token automatically on first login." -ForegroundColor Gray
Write-Host "2) Watch push-service logs: docker compose logs -f push-service" -ForegroundColor Gray
Write-Host "3) For live demo, push a test stream to rtsp://127.0.0.1:8554/$StreamKey:" -ForegroundColor Gray
Write-Host "   docker compose exec -d ffmpeg_rtsp_cam1 sh -lc 'ffmpeg -re -f lavfi -i testsrc=size=640x360:rate=25 -f lavfi -i sine=frequency=1000:sample_rate=48000 -c:v libx264 -preset veryfast -tune zerolatency -pix_fmt yuv420p -profile:v main -g 50 -c:a aac -b:a 128k -f rtsp -rtsp_transport tcp rtsp://mediamtx:8554/$StreamKey'" -ForegroundColor Gray
Write-Host "4) Open app: Camera → Watch Live, History → open anomaly detail (clip presigned if provided)." -ForegroundColor Gray

