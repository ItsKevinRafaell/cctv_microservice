Usage

- Stream your webcam as cam3 (recommended for live):
  1) Ensure Docker is running.
  2) Seed Company 3 and camera with stream_key=cam3 (optional but useful):
     - bash scripts/seed_company3.sh
  3) One-command bring-up + auto webcam stream:
     - PowerShell: powershell -ExecutionPolicy Bypass -File scripts/run_with_webcam.ps1
     - Optional device: ... -VideoDevice "Integrated Camera"
  4) Verify HLS: open http://127.0.0.1:8888/cam3/index.m3u8

- Upload short webcam clips to ingestion (for anomaly pipeline/tests):
  - From webcam: `python cctv-camera/send_webcam_clips.py --camera-id <numeric_id> [--seconds 10] [--fps 15]`
  - From existing RTSP stream (no second webcam handle):
    `python cctv-camera/send_webcam_clips.py --camera-id <numeric_id> --source rtsp://127.0.0.1:8554/cam3 --seconds 10 --no-preview`
  - If you publish via RTMP or RTSP fails to open in OpenCV, use ffmpeg capture (robust):
    `python cctv-camera/send_webcam_clips.py --camera-id <numeric_id> --source rtmp://127.0.0.1:1935/cam3 --seconds 8 --no-preview --ffmpeg-capture`
  - `camera_id` is the numeric id of your camera (the seeder prints it).
