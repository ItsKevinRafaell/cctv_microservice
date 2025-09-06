# End‑to‑End Guide (Fresh Setup)

This guide takes you from a clean Docker stack to a working demo: live streaming, recordings, anomaly creation, and push notifications that deep‑link into the app.

Prerequisites
- Docker & Docker Compose
- Git Bash / Bash (for scripts) or PowerShell
- Android Emulator with Google Play Services (or a physical Android device)

Ports
- Backend: 8080
- Ingestion: 8081
- MediaMTX: RTSP 8554, HLS 8888, WebRTC WS 8889
- MinIO: 9000 (S3), 9001 (Console)
- Push Service: 8090
- Recording Indexer: 8091

Important (Android Emulator)
- Use `10.0.2.2` to reach the host from the emulator. The backend is configured to presign MinIO URLs with `http://10.0.2.2:9000` so clips are reachable.
- Run the app with:
  - `--dart-define=API_BASE_URL=http://10.0.2.2:8080`
  - `--dart-define=HLS_BASE_URL=http://10.0.2.2:8888`

0) Fresh Start
```bash
docker compose down -v
docker compose up -d --build

# Health checks
curl -s http://127.0.0.1:8080/healthz
curl -s http://127.0.0.1:8080/api/health/report | jq -c .
```

1) App: Run & Login
- `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080 --dart-define=HLS_BASE_URL=http://10.0.2.2:8888`
- Login as superadmin (seeded via env): `superadmin@example.com / ChangeMe123!`
- Or user created below (`company3admin@example.com / Passw0rd123!`).

2) Seed Company 3 Admin, Camera, & Anomaly
```bash
# Create/ensure company admin, camera cam3, and one anomaly
./scripts/seed_company3.sh
```
Notes:
- The script logs in as superadmin and creates the user `company3admin@example.com` (company_id=3) and a camera with stream_key `cam3` (company 3).
- It also reports one anomaly for that camera.

3) Start Dummy Live Stream (cam3)
```bash
# Starts a publisher that pushes RTSP test pattern to MediaMTX for cam3
docker compose up -d mediamtx test_publisher_cam3

# Verify HLS
curl -s http://127.0.0.1:8888/cam3/index.m3u8 | head
```
- In the app: open the camera → “Watch Live”.

4) Recordings
- `archiver_manager` is configured to segment every 60s and includes cam3.
- Wait 1–2 minutes. Check:
  - MinIO Console: http://127.0.0.1:9001 → bucket `video-archive`
  - App → Camera → “Recordings” lists segments; items use presigned URLs.

5) Anomaly Clip (optional)
- Upload a clip into MinIO: bucket `video-clips`, key `cam3/clip_001.mp4`.
- Report another anomaly with this clip path:
```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:8080/api/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"superadmin@example.com","password":"ChangeMe123!"}' | jq -r .token)

curl -s -X POST http://127.0.0.1:8080/api/report-anomaly \
  -H 'Content-Type: application/json' \
  -d '{"camera_id":3,"anomaly_type":"intrusion","confidence":0.9,"video_clip_url":"/video-clips/cam3/clip_001.mp4","reported_at":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}'

# In app → History → open the latest anomaly → press Play Clip
```

6) Push Notifications
Ensure the app:
- Shows a token in Settings and “Push notifications” is Enabled.
- Background the app to see a system notification.

Send push via backend (uses company tokens):
```bash
curl -s -X POST http://127.0.0.1:8080/api/notifications/test \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -c .
# Response includes anomaly_id & tokens_count
```

Send direct to your device (bypass mapping):
```bash
# Replace <TOKEN> with the token shown in the app Settings
# Replace <ANOMALY_ID> with a valid numeric id from /api/anomalies/recent
curl -s -X POST http://127.0.0.1:8090/send \
  -H 'Content-Type: application/json' -H 'X-Push-Secret: change-me-secret' \
  -d '{"tokens":["<TOKEN>"],"title":"Test","body":"Hello","data":{"type":"anomaly","anomaly_id":"<ANOMALY_ID>"}}'
```

Troubleshooting
- No clip playback? Ensure anomaly detail returns `video_clip_url` starting with `http://10.0.2.2:9000/...` and the object exists in MinIO.
- No push? Confirm:
  - App token visible and re-upserted (re-login if needed).
  - `api_main` logs: “Notifier: HTTP push-service”.
  - `push-service` logs show a send attempt; use a Google Play emulator.
- 404 on tap? Push payload must include a valid numeric `anomaly_id` for the user’s company.

