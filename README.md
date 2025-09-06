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
