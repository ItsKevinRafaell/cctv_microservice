# API & Data Setup

Base URL (host): `http://127.0.0.1:8080` (emulator uses `http://10.0.2.2:8080`)

Auth
- POST `/api/login`
  - body: `{ "email":"...", "password":"..." }`
  - returns: `{ "token": "..." }`
- POST `/api/register` (auth; role‑guarded)
  - body: `{ "email", "password", "company_id", "role" }`

Users
- GET `/api/users` (auth)
- PUT `/api/users/{id}` (auth; company_admin) → change role
- DELETE `/api/users/{id}` (auth; company_admin)
- POST `/api/users/fcm-token` (auth) → `{ "fcm_token": "..." }`

Companies (superadmin)
- POST `/api/companies` → `{ "name": "..." }` returns `{ "company_id": n }`
- GET `/api/companies`
- PUT `/api/companies/{id}`
- DELETE `/api/companies/{id}`

Cameras
- POST `/api/cameras` (auth)
  - body: `{ "name": "Demo Cam", "location": "...", "stream_key":"cam3", "company_id": 3 }`
  - returns: `{ camera_id, stream_key, hls_url, rtsp_url, webrtc_url }`
- GET `/api/cameras` (auth) → list (superadmin can pass `?company_id=`)
- PUT `/api/cameras/{id}` (auth)
- DELETE `/api/cameras/{id}` (auth)
- GET `/api/cameras/{id or stream_key}/recordings?from=&to=&presign=1` (auth)

Anomalies
- POST `/api/report-anomaly`
  - body: `{ "camera_id": <numeric>, "anomaly_type":"intrusion", "confidence":0.9, "video_clip_url":"/video-clips/cam3/clip_001.mp4", "reported_at":"<ISO8601 UTC>" }`
  - If `WORKER_SHARED_TOKEN` is set, include header `X-Worker-Token: <token>`
  - Triggers push notifications automatically when saved.
- GET `/api/anomalies` (auth)
- GET `/api/anomalies/recent` (auth)
- GET `/api/anomalies/{id}` (auth) → returns presigned `video_clip_url` if configured

Notifications (test helper)
- POST `/api/notifications/test` (auth)
  - body: `{ "anomaly_id": 123 }` (optional; if omitted, uses latest anomaly for caller’s company)
  - sends push via push‑service and returns `{ ok, anomaly_id, tokens_count }`

Data Setup Cheatsheet (PowerShell)
- Login → JWT
```
$login = Invoke-RestMethod -Uri http://127.0.0.1:8080/api/login -Method POST -ContentType 'application/json' -Body '{"email":"superadmin@example.com","password":"ChangeMe123!"}'; $TOKEN = $login.token
```
- Get `cam3` numeric id
```
$cams = Invoke-RestMethod -Uri http://127.0.0.1:8080/api/cameras -Headers @{ Authorization = "Bearer $TOKEN" }
$camId = ($cams | Where-Object { $_.stream_key -eq 'cam3' }).id
```
- Report anomaly (no worker token)
```
$body = @{ camera_id=[int]$camId; anomaly_type='intrusion'; confidence=0.92; reported_at=(Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json
Invoke-RestMethod -Uri http://127.0.0.1:8080/api/report-anomaly -Method POST -ContentType 'application/json' -Body $body
```
- With clip (upload `clip-dummy/clip_001.mp4` to MinIO → bucket `video-clips` key `cam3/clip_001.mp4` first)
```
$body = @{ camera_id=[int]$camId; anomaly_type='intrusion'; confidence=0.92; video_clip_url='/video-clips/cam3/clip_001.mp4'; reported_at=(Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json
Invoke-RestMethod -Uri http://127.0.0.1:8080/api/report-anomaly -Method POST -ContentType 'application/json' -Body $body
```
- Send test push via backend (deep‑link to latest anomaly)
```
Invoke-RestMethod -Uri http://127.0.0.1:8080/api/notifications/test -Method POST -Headers @{ Authorization = "Bearer $TOKEN" }
```

Build & Run
- One‑liner: `docker compose up -d --build`
- Seed sample data: `bash scripts/seed_company3.sh`
- Start dummy live: `docker compose up -d mediamtx test_publisher_cam3`
- App run: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080 --dart-define=HLS_BASE_URL=http://10.0.2.2:8888`

