#!/usr/bin/env python3
"""
Send short video clips from the remote laptop into the ingestion service.

Usage examples:
  # Capture from the already published stream (recommended)
  python send_clips.py --camera-id 5 --source rtsp://192.168.1.10:8554/cam4 --seconds 8 --ffmpeg-capture --no-preview

  # Capture directly from the local webcam
  python send_clips.py --camera-id 5 --seconds 10 --fps 15
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import subprocess
import tempfile
import time
from pathlib import Path

try:
    import cv2
except ImportError as exc:  # pragma: no cover
    raise SystemExit("Module 'cv2' tidak ditemukan. Jalankan 'pip install -r requirements.txt' terlebih dahulu.") from exc

try:
    import requests
except ImportError as exc:  # pragma: no cover
    raise SystemExit("Module 'requests' tidak ditemukan. Jalankan 'pip install -r requirements.txt' terlebih dahulu.") from exc


ROOT = Path(__file__).resolve().parent


def load_env() -> dict[str, str]:
    env_path = ROOT / ".env"
    values: dict[str, str] = {}
    if not env_path.exists():
        return values
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def env_bool(env: dict[str, str], key: str, default: bool = False) -> bool:
    val = env.get(key)
    if val is None:
        return default
    return val.lower() in {"1", "true", "yes", "on"}


def with_env_defaults(parser: argparse.ArgumentParser, env: dict[str, str]) -> argparse.Namespace:
    args = parser.parse_args()
    if args.ingest_url is None:
        host = env.get("HOST")
        default_ingest = f"http://{host}:8081/ingest/video" if host else None
        args.ingest_url = env.get("INGEST_URL", default_ingest or "http://localhost:8081/ingest/video")
    if args.camera_id is None:
        args.camera_id = env.get("CAMERA_ID")
    if args.seconds is None:
        args.seconds = int(env.get("CLIP_SECONDS", "8"))
    if args.fps is None:
        args.fps = int(env.get("CLIP_FPS", "15"))
    if args.width is None:
        args.width = int(env.get("CLIP_WIDTH", "640"))
    if args.height is None:
        args.height = int(env.get("CLIP_HEIGHT", "360"))
    if args.source is None:
        args.source = env.get("CLIP_SOURCE", "")
    if not args.no_preview:
        args.no_preview = env_bool(env, "NO_PREVIEW", False)
    if not args.ffmpeg_capture:
        args.ffmpeg_capture = env_bool(env, "FFMPEG_CAPTURE", True)
    if not args.copy_stream:
        args.copy_stream = env_bool(env, "COPY_STREAM", False)
    if not args.loop:
        args.loop = env_bool(env, "CLIP_LOOP", False)
    if args.interval is None:
        args.interval = int(env.get("CLIP_INTERVAL", "10"))
    if args.ffmpeg_path is None:
        args.ffmpeg_path = env.get("FFMPEG_PATH") or "ffmpeg"
    if args.rtsp_transport is None:
        args.rtsp_transport = env.get("RTSP_TRANSPORT", "tcp")
    if not args.force_anomaly:
        args.force_anomaly = env_bool(env, "FORCE_ANOMALY", False)
    return args


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Upload short clips to the ingestion service.")
    p.add_argument("--ingest-url", help="Endpoint ingest service (default: http://<HOST>:8081/ingest/video)")
    p.add_argument("--camera-id", help="ID kamera di backend (CAMERA_ID)")
    p.add_argument("--seconds", type=int, help="Durasi klip (CLIP_SECONDS)")
    p.add_argument("--fps", type=int, help="FPS capture (CLIP_FPS)")
    p.add_argument("--width", type=int, help="Lebar frame (CLIP_WIDTH)")
    p.add_argument("--height", type=int, help="Tinggi frame (CLIP_HEIGHT)")
    p.add_argument("--source", help="Sumber video (rtsp/rtmp/file). Kosongkan untuk webcam.")
    p.add_argument("--no-preview", action="store_true", help="Matikan preview OpenCV (NO_PREVIEW)")
    p.add_argument("--ffmpeg-capture", action="store_true", help="Gunakan ffmpeg CLI untuk capture stream (FFMPEG_CAPTURE)")
    p.add_argument("--ffmpeg-path", help="Lokasi ffmpeg (FFMPEG_PATH)")
    p.add_argument("--rtsp-transport", help="Transport RTSP (tcp/udp) (RTSP_TRANSPORT)")
    p.add_argument("--force-anomaly", action="store_true", help="Tambahkan suffix -anomaly untuk memaksa flag anomaly")
    p.add_argument("--loop", action="store_true", help="Terus mengirim klip berulang (CLIP_LOOP)")
    p.add_argument("--interval", type=int, help="Jeda detik antar klip saat loop (CLIP_INTERVAL)")
    p.add_argument("--copy-stream", action="store_true", help="Skip transcode; gunakan -c copy saat merekam (COPY_STREAM)")
    return p


def ensure_args(args: argparse.Namespace) -> None:
    if not args.camera_id:
        raise ValueError("camera_id belum diisi. Set --camera-id atau CAMERA_ID di .env")
    if not args.ingest_url:
        raise ValueError("ingest_url belum diisi. Set --ingest-url atau HOST/INGEST_URL di .env")


def record_with_ffmpeg(args: argparse.Namespace, temp_path: str) -> int:
    cmd = [args.ffmpeg_path, "-y"]
    if args.source.lower().startswith("rtsp://"):
        cmd += ["-rtsp_transport", args.rtsp_transport]
    cmd += ["-i", args.source, "-t", str(max(1, args.seconds)), "-an"]
    if args.copy_stream:
        cmd += ["-c", "copy", "-movflags", "+faststart"]
    else:
        cmd += [
            "-c:v",
            "libx264",
            "-preset",
            "veryfast",
            "-pix_fmt",
            "yuv420p",
            "-movflags",
            "+faststart",
        ]
    cmd.append(temp_path)
    print("FFmpeg capture:", " ".join(subprocess.list2cmdline([c]) if " " in c else c for c in cmd))
    subprocess.run(cmd, check=True, timeout=max(10, args.seconds + 20))
    return 1


def main() -> None:
    parser = build_parser()
    env = load_env()
    args = with_env_defaults(parser, env)
    ensure_args(args)

    frame_size = (args.width, args.height)
    clip_seconds = max(1, args.seconds)
    use_time_limit = True

    if args.source:
        cap = cv2.VideoCapture(args.source, cv2.CAP_FFMPEG)
        if not cap.isOpened():
            if args.ffmpeg_capture:
                cap = None
            else:
                raise RuntimeError(f"Tidak bisa membuka source: {args.source}. Tambahkan --ffmpeg-capture.")
    else:
        cap = cv2.VideoCapture(0, cv2.CAP_DSHOW) if hasattr(cv2, "CAP_DSHOW") else cv2.VideoCapture(0)
        if not cap.isOpened():
            raise RuntimeError("Tidak bisa membuka webcam (index 0). Tambahkan --source bila ingin pakai stream.")
        if args.fps > 0:
            cap.set(cv2.CAP_PROP_FPS, args.fps)
        use_time_limit = False

    fourccs = [cv2.VideoWriter_fourcc(*"mp4v"), cv2.VideoWriter_fourcc(*"XVID")]
    print(f"Source={args.source or 'webcam:0'} -> {clip_seconds}s @ {args.fps}fps, upload to {args.ingest_url}, camera_id={args.camera_id}")

    try:
        while True:
            ts = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
            suffix = "-anomaly" if args.force_anomaly else ""
            filename = f"{ts}{suffix}.mp4"
            temp_path = os.path.join(tempfile.gettempdir(), filename)

            start = time.time()
            grabbed = 0

            if args.source and cap is None and args.ffmpeg_capture:
                record_with_ffmpeg(args, temp_path)
                grabbed = 1
            else:
                writer = None
                for fourcc in fourccs:
                    writer = cv2.VideoWriter(temp_path, fourcc, args.fps if args.fps > 0 else 15, frame_size)
                    if writer.isOpened():
                        break
                if writer is None or not writer.isOpened():
                    raise RuntimeError("Gagal membuka VideoWriter. Coba turunkan FPS/resolusi.")

                target_frames = int(args.fps * clip_seconds) if args.fps > 0 else 0
                end_time = start + clip_seconds
                while True:
                    ok, frame = cap.read()
                    if not ok:
                        break
                    frame = cv2.resize(frame, frame_size)
                    writer.write(frame)
                    grabbed += 1

                    if use_time_limit and time.time() >= end_time:
                        break
                    if not use_time_limit and target_frames and grabbed >= target_frames:
                        break

                    if not args.no_preview:
                        display = frame.copy()
                        progress = f"{grabbed}f" if use_time_limit else f"{grabbed}/{target_frames}"
                        cv2.putText(display, f"REC {progress}", (10, 24), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
                        cv2.imshow("Clip uploader", display)
                        if cv2.waitKey(1) & 0xFF == ord("q"):
                            writer.release()
                            cap.release()
                            cv2.destroyAllWindows()
                            return

                writer.release()

            if grabbed == 0 or not os.path.exists(temp_path):
                print("Tidak ada frame, skip upload.")
            else:
                with open(temp_path, "rb") as f:
                    files = {"video_clip": (filename, f, "video/mp4")}
                    data = {"camera_id": str(args.camera_id)}
                    response = requests.post(args.ingest_url, files=files, data=data, timeout=90)
                    elapsed = time.time() - start
                    print(f"[{ts}] upload {filename} -> {response.status_code}: {response.text[:120]} (took {elapsed:.1f}s)")
            try:
                os.remove(temp_path)
            except OSError:
                pass
            if not args.loop:
                break
            sleep_for = max(0, args.interval)
            if sleep_for:
                print(f"[loop] Menunggu {sleep_for}s sebelum klip berikutnya...")
                time.sleep(sleep_for)
    except KeyboardInterrupt:
        print("\n[stop] Dihentikan oleh user.")
    finally:
        if 'cap' in locals() and cap is not None:
            cap.release()
        cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
