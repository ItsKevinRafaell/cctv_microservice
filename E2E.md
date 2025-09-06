# End‑to‑End Guide (Fresh Setup)

This guide takes you from a clean Docker stack to a working demo: live streaming, recordings, anomaly creation, and push notifications that deep‑link into the app.

Prerequisites
- Docker & Docker Compose
- Git Bash / Bash (for scripts) or PowerShell
- Android Emulator with Google Play Services (or a physical Android device)

Ports
- Backend: 8080
- MediaMTX: RTSP 8554, HLS 8888, WebRTC WS 8889
- MinIO: 9000 (S3), 9001 (Console)
- Push Service: 8090
- Recording Indexer: 8091

Important (Android Emulator)
- Use `10.0.2.2` to reach the host from the emulator. The backend presigns MinIO URLs with `http://10.0.2.2:9000` so clips are reachable.
- Run the app with:
  - `--dart-define=API_BASE_URL=http://10.0.2.2:8080`
  - `--dart-define=HLS_BASE_URL=http://10.0.2.2:8888`

0) Fresh Start
```bash
docker compose up -d --build
# Optional health
curl -s http://127.0.0.1:8080/healthz
```

1) App: Run & Login
- `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080 --dart-define=HLS_BASE_URL=http://10.0.2.2:8888`
- Login: `company3admin@example.com / Passw0rd123!` (seeded below)

2) Seed Company 3 Admin, Camera, & Anomaly
```bash
bash scripts/seed_company3.sh
```
- Creates company “Company 3”, user `company3admin@example.com`, camera `stream_key=cam3`, and one anomaly.

3) Start Dummy Live Stream (cam3)
```bash
docker compose up -d mediamtx test_publisher_cam3
curl -s http://127.0.0.1:8888/cam3/index.m3u8 | head
```
- In the app: open the camera → Watch Live.

4) Recordings
- `archiver_manager` segments every 60s for `cam3`.
- Wait 1–2 minutes; check MinIO Console (http://127.0.0.1:9001) bucket `video-archive`.
- App → Camera → Recordings shows presigned items.

5) Anomaly Clip (optional)
- Upload a clip into MinIO: bucket `video-clips`, key `cam3/clip_001.mp4`.
- A ready dummy file is provided at `clip-dummy/clip_001.mp4`.
- Report an anomaly with this clip path (see `API.md`).
- In app: History → latest anomaly → press Play Clip.

6) Push Notifications
- In the app, Settings shows the token and “Push notifications” is Enabled.
- Background the app to see system notifications.
- Send via backend (uses company tokens): Settings → “Send Test Notification (latest anomaly)”.
- Or send direct to a token via push-service (see `API.md`).

Troubleshooting
- Live 404: ensure `test_publisher_cam3` is running and HLS exists.
- Clip 404: ensure object exists in MinIO and anomaly detail returns a URL with host `http://10.0.2.2:9000`.
- No push: background the app, verify token is visible, push-service logs show a send; app & push-service must share the same Firebase project.
- 404 on tap: the push payload must include a valid numeric `anomaly_id` for the user’s company.
