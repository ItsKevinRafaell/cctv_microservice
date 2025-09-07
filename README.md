# AnomEye CCTV Microservice Suite

End-to-end CCTV microservice stack with live streaming, anomaly reporting, recordings, and push notifications to a Flutter app.

Components
- cctv-main-backend (Go): REST API, DB migrations, S3/MinIO presign, push notifier integration.
- mediamtx (RTSP/HLS/WebRTC): media server; publish RTSP and play HLS.
- recording-indexer (Go): indexes long recordings stored to MinIO.
- archiver_manager (FFmpeg): segments long RTSP -> MP4 to MinIO (mirrored by archive_sync).
- push-service (Go): receives requests from backend and sends FCM notifications.
- app-client (Flutter): Android app (Riverpod + go_router) for live, history, recordings, and push deep-links.

Quick Start
- Build & run everything
  - `docker compose up -d --build`
- Seed demo user, camera, and anomaly (company 3, stream_key cam3).
  - `bash scripts/seed_company3.sh`
  - Catatan: payload anomaly default menyertakan `video_clip_url: /video-clips/cam3/clip_001.mp4`. Anda yang akan mengunggah filenya ke MinIO.
  - Script juga memicu notifikasi test otomatis setelah membuat anomaly.
- Start a dummy live stream to cam3 (HLS: http://127.0.0.1:8888/cam3/index.m3u8)
  - `docker compose up -d mediamtx test_publisher_cam3`
- Use your webcam as cam3 (Windows):
  - RTMP (recommended): `powershell -ExecutionPolicy Bypass -File cctv-camera/start_cam3_stream.ps1 -VideoDevice "Integrated Camera" -Fps 30 -Size "640x480" -NoScale -Protocol rtmp`
  - Send clips to AI (from stream, no second webcam handle):
    `python cctv-camera/send_webcam_clips.py --camera-id <ID> --source rtmp://127.0.0.1:1935/cam3 --seconds 8 --no-preview --ffmpeg-capture --force-anomaly`
  - More options: see `cctv-camera/README.md`.
- Run the app (Android emulator)
  - `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080 --dart-define=HLS_BASE_URL=http://10.0.2.2:8888`
  - Login: `company3admin@example.com / Passw0rd123!`

What works
- Live HLS playback (cam3).
- Recordings list with presigned URLs (after ~1–2 minutes).
- Anomalies list & detail; clip playback (upload clip sendiri ke MinIO bila diperlukan).
- Push notifications with deep-link to anomaly detail (tap test in Settings or report a real anomaly).

Notes
- For the emulator, backend presigns MinIO URLs with `http://10.0.2.2:9000` so clips are reachable.
- REST usage and data setup: `API.md`.

## MVP Quick Start (Step-by-Step)

1) Compose Up Services (ensure `api_main` runs)
   - Command: `docker compose up -d --build`
   - Verify: `docker compose ps` → `api_main` should be Up on `0.0.0.0:8080`

2) Run The App (set API/HLS base URLs)
   - Android emulator: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080 --dart-define=HLS_BASE_URL=http://10.0.2.2:8888`
   - Desktop/Web on same host: `API_BASE_URL=http://127.0.0.1:8080` and `HLS_BASE_URL=http://127.0.0.1:8888`

3) Seed Demo Data (Company 3 + Camera `cam3`)
   - Command (Git Bash/WSL): `bash scripts/seed_company3.sh`
   - Output shows `camera_id` and triggers a test notification when possible.
   - App login: `company3admin@example.com / Passw0rd123!`

4) Start Live Streaming To MediaMTX
   - Windows (recommended RTMP):
     - `powershell -ExecutionPolicy Bypass -File cctv-camera/start_cam3_stream.ps1 -VideoDevice "Integrated Camera" -Fps 30 -Size "640x480" -NoScale -Protocol rtmp`
   - Alternative RTSP (if it works on your device):
     - `powershell -ExecutionPolicy Bypass -File cctv-camera/start_cam3_stream.ps1 -VideoDevice "Integrated Camera" -Fps 30 -Size "640x480" -NoScale`
   - Play HLS in VLC: `http://127.0.0.1:8888/cam3/index.m3u8` or WebRTC test page: `http://127.0.0.1:8889/cam3`

5) Send Short Clips To AI (from the same stream)
   - Robust on Windows (read RTMP with ffmpeg):
     - `python cctv-camera/send_webcam_clips.py --camera-id <ID> --source rtmp://127.0.0.1:1935/cam3 --seconds 8 --no-preview --ffmpeg-capture --force-anomaly`
   - This uploads MP4 clips to the ingestion service → AI worker analyzes → backend receives anomaly.

6) Watch Logs (ingestion + AI worker)
   - `docker compose logs -f api_ingestion ai_worker`
   - Look for: ingestion 200 OK and AI worker sending a report to backend.

7) Test Push Notification
   - From the app Settings: tap “Test Notification” (uses the latest anomaly).
   - Or check `docker compose logs -f push-service` while seeding/tests run.

Notes
- If you need a clean slate, run `docker compose down -v` then repeat steps 1–7 and re-run the seeder (step 3).
- For emulator networking, always use `10.0.2.2` for host URLs.
- Long recordings to MinIO (optional): `docker compose up -d archiver_manager archive_sync recording_indexer`; recordings appear in MinIO Console at `http://127.0.0.1:9001` (user `minioadmin`, pass `minio-secret-key`).
