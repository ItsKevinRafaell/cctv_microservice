Usage

This folder lets you turn your PC webcam into a camera for the stack (live HLS via MediaMTX) and send short clips into the AI pipeline for anomaly detection.

**Prereqs**
- Docker Desktop running.
- Windows PowerShell available (for streaming script).
- Python 3.9+ with `pip install opencv-python requests` if you will run the clip uploader.

**Quick Steps**
- Seed demo data (optional, prints `camera_id`):
  - `bash scripts/seed_company3.sh`
- Start all services: `docker compose up -d --build`
- Stream webcam to `cam3` (RTMP is the most stable on Windows):
  - `powershell -ExecutionPolicy Bypass -File cctv-camera/start_cam3_stream.ps1 -VideoDevice "Integrated Camera" -Fps 30 -Size "640x480" -NoScale -Protocol rtmp`
- Watch HLS: `http://127.0.0.1:8888/cam3/index.m3u8` (use VLC/ffplay) or WebRTC page: `http://127.0.0.1:8889/cam3`
- Send clips from the live stream to the AI worker:
  - `python cctv-camera/send_webcam_clips.py --camera-id <ID> --source rtmp://127.0.0.1:1935/cam3 --seconds 8 --no-preview --ffmpeg-capture --force-anomaly`

**Live Streaming (Webcam → MediaMTX)**
- RTMP (recommended on Windows):
  - `powershell -ExecutionPolicy Bypass -File cctv-camera/start_cam3_stream.ps1 -VideoDevice "Integrated Camera" -Fps 30 -Size "640x480" -NoScale -Protocol rtmp`
- RTSP (alternative / works for remote host as well):
  - Lokal: `powershell -ExecutionPolicy Bypass -File cctv-camera/start_cam3_stream.ps1 -VideoDevice "Integrated Camera" -Fps 30 -Size "640x480" -NoScale`
  - Remote (ke host lain): `powershell -ExecutionPolicy Bypass -File cctv-camera/start_cam3_stream.ps1 -VideoDevice "Integrated Camera" -RtspUrl "rtsp://<HOST_DOCKER>:8554/cam3"`  
    (Script mendeteksi host bukan lokal dan otomatis melewati `docker compose up`; bisa pakai `-SkipDocker` untuk memaksa skip.)
- One-command bring-up + stream (auto-stops dummy publisher, ensures MediaMTX; gunakan hanya di mesin yang menjalankan docker-compose):
  - `powershell -ExecutionPolicy Bypass -File scripts/run_with_webcam.ps1 [-VideoDevice "Integrated Camera"]`

**View Stream**
- HLS (VLC): open `http://127.0.0.1:8888/cam3/index.m3u8`.
- WebRTC test page (browser): `http://127.0.0.1:8889/cam3` → Read.
- RTSP (VLC): `rtsp://127.0.0.1:8554/cam3`.

**Send Clips to AI (Anomaly Pipeline)**
- From webcam device (opens camera):
  - `python cctv-camera/send_webcam_clips.py --camera-id <ID> --seconds 10 --fps 15`
- From the existing stream (does NOT open webcam again):
  - RTSP source: `python cctv-camera/send_webcam_clips.py --camera-id <ID> --source rtsp://127.0.0.1:8554/cam3 --seconds 8 --no-preview`
  - RTMP source (robust; preferred when publishing via RTMP):
    `python cctv-camera/send_webcam_clips.py --camera-id <ID> --source rtmp://127.0.0.1:1935/cam3 --seconds 8 --no-preview --ffmpeg-capture`
- Notes:
  - `--force-anomaly` is useful for smoke-testing the end-to-end anomaly flow.
  - `camera_id` is the numeric ID printed by the seeder or available via `GET /api/cameras`.

**Recordings to MinIO (long recordings)**
- Start the archiver + sync + indexer:
  - `docker compose up -d archiver_manager archive_sync recording_indexer`
- Check MinIO Console: `http://127.0.0.1:9001` (user `minioadmin`, pass `minio-secret-key`). Files appear in bucket `video-archive`.
- The indexer writes recordings to DB; they show up in the app after ~1–2 minutes.

**Troubleshooting**
- HLS 404: no publisher on `cam3`. Start the stream first.
- Browser downloads `.m3u8`: use VLC/ffplay, or WebRTC page `:8889/cam3`.
- RTSP “Could not write header” from ffmpeg: use `-Protocol rtmp`.
- OpenCV can’t open RTSP/RTMP: pass `--ffmpeg-capture` or use the RTMP source URL.
- Port conflicts: free up 8554/1935/8888/8889 or change mappings in `docker-compose.yml`.
