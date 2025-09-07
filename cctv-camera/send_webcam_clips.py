"""Webcam/stream clip uploader.

Examples:
  # From local webcam
  python cctv-camera/send_webcam_clips.py --camera-id 3 --seconds 10 --fps 15

  # From existing stream (RTSP/RTMP) without opening webcam again
  python cctv-camera/send_webcam_clips.py --camera-id 3 \
    --source rtsp://127.0.0.1:8554/cam3 --seconds 8 --no-preview

  # Force ffmpeg-based capture (more robust for RTSP/RTMP)
  python cctv-camera/send_webcam_clips.py --camera-id 3 \
    --source rtmp://127.0.0.1:1935/cam3 --seconds 8 --ffmpeg-capture
"""

import argparse
import datetime as dt
import os
import tempfile
import time

import cv2
import requests


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument('--ingest-url', default=os.getenv('INGEST_URL', 'http://localhost:8081/ingest/video'))
    p.add_argument('--camera-id', default=os.getenv('CAMERA_ID', '2'))
    p.add_argument('--seconds', type=int, default=int(os.getenv('CLIP_SECONDS', '10')))
    p.add_argument('--fps', type=int, default=int(os.getenv('FPS', '15')))
    p.add_argument('--width', type=int, default=int(os.getenv('FRAME_WIDTH', '640')))
    p.add_argument('--height', type=int, default=int(os.getenv('FRAME_HEIGHT', '360')))
    p.add_argument('--source', default=os.getenv('VIDEO_SOURCE', ''), help='Optional: RTSP/RTMP/HTTP/file source. If empty, use local webcam.')
    p.add_argument('--no-preview', action='store_true', default=os.getenv('NO_PREVIEW', 'false').lower() == 'true')
    p.add_argument('--ffmpeg-capture', action='store_true', default=os.getenv('FFMPEG_CAPTURE', 'false').lower() == 'true',
                   help='Use ffmpeg CLI to record clips from --source (robust for RTSP/RTMP).')
    p.add_argument('--ffmpeg-path', default=os.getenv('FFMPEG_PATH', 'ffmpeg'), help='ffmpeg executable path (if using --ffmpeg-capture).')
    p.add_argument('--rtsp-transport', default=os.getenv('RTSP_TRANSPORT', 'tcp'), help='rtsp transport (tcp|udp) when using --source rtsp://')
    p.add_argument('--force-anomaly', action='store_true', default=os.getenv('FORCE_ANOMALY', 'false').lower() == 'true')
    return p.parse_args()


def main():
    args = parse_args()
    frame_size = (args.width, args.height)
    n_frames = int(args.seconds * args.fps) if args.fps > 0 else 0

    if args.source:
        # Try OpenCV FFMPEG backend first; if fails and --ffmpeg-capture given, use ffmpeg CLI fallback.
        cap = cv2.VideoCapture(args.source, cv2.CAP_FFMPEG)
        if not cap.isOpened():
            if args.ffmpeg_capture:
                cap = None
            else:
                raise RuntimeError(f'Tidak bisa membuka source: {args.source}. Coba tambah --ffmpeg-capture atau gunakan --source rtmp://127.0.0.1:1935/cam3')
        # For RTSP/RTMP/file sources, prefer time-based loop
        use_time_limit = True
    else:
        cap = cv2.VideoCapture(0, cv2.CAP_DSHOW) if hasattr(cv2, 'CAP_DSHOW') else cv2.VideoCapture(0)
        if not cap.isOpened():
            raise RuntimeError('Tidak bisa membuka webcam (index 0).')
        if args.fps > 0:
            cap.set(cv2.CAP_PROP_FPS, args.fps)
        use_time_limit = False
    fourccs = [cv2.VideoWriter_fourcc(*'mp4v'), cv2.VideoWriter_fourcc(*'XVID')]

    src_desc = args.source if args.source else 'webcam:0'
    print(f"Source={src_desc} -> {args.seconds}s/clip @ {args.fps} FPS, upload to {args.ingest_url}, camera_id={args.camera_id}")
    try:
        while True:
            ts = dt.datetime.now().strftime('%Y%m%d-%H%M%S')
            suffix = '-anomaly' if args.force_anomaly else ''
            filename = f"{ts}{suffix}.mp4"
            temp_path = os.path.join(tempfile.gettempdir(), filename)

            if args.source and (cap is None) and args.ffmpeg_capture:
                # FFMPEG fallback recording (no OpenCV capture)
                import subprocess, shlex
                start = time.time()
                grabbed = 1  # placeholder, we don't know exact frames
                # Build ffmpeg command
                cmd = [args.ffmpeg_path, '-y']
                if args.source.lower().startswith('rtsp://'):
                    cmd += ['-rtsp_transport', args.rtsp_transport]
                cmd += ['-i', args.source, '-t', str(max(1, args.seconds)), '-an',
                        '-c:v', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p',
                        '-movflags', '+faststart', temp_path]
                print('FFmpeg capture:', ' '.join(shlex.quote(x) for x in cmd))
                try:
                    subprocess.run(cmd, check=True, timeout=max(5, args.seconds + 15))
                except subprocess.CalledProcessError as e:
                    print(f'ffmpeg capture failed: {e}')
                except subprocess.TimeoutExpired:
                    print('ffmpeg capture timeout')
            else:
                writer = None
                for fourcc in fourccs:
                    writer = cv2.VideoWriter(temp_path, fourcc, args.fps if args.fps > 0 else 15, frame_size)
                    if writer.isOpened():
                        break
                if writer is None or not writer.isOpened():
                    raise RuntimeError('Gagal membuka VideoWriter. Coba turunkan resolusi/FPS.')

                grabbed = 0
                start = time.time()
                end_time = start + max(0, args.seconds)
                while True:
                    ok, frame = cap.read()
                    if not ok:
                        break
                    frame = cv2.resize(frame, frame_size)
                    writer.write(frame)
                    grabbed += 1

                    # Stop condition
                    if use_time_limit:
                        if time.time() >= end_time:
                            break
                    else:
                        if n_frames > 0 and grabbed >= n_frames:
                            break

                    # Preview (optional)
                    if not args.no_preview:
                        disp = frame.copy()
                        progress = f"{grabbed}f" if use_time_limit else f"{grabbed}/{n_frames}"
                        cv2.putText(disp, f"REC {progress}", (10, 24), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
                        cv2.putText(disp, 'q: quit', (10, frame_size[1] - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)
                        cv2.imshow('Video -> Ingestion', disp)
                        if cv2.waitKey(1) & 0xFF == ord('q'):
                            writer.release()
                            cap.release()
                            cv2.destroyAllWindows()
                            return

                writer.release()

            if grabbed == 0 or not os.path.exists(temp_path):
                print('Tidak ada frame terekam, skip upload.')
            else:
                try:
                    with open(temp_path, 'rb') as f:
                        files = {'video_clip': (filename, f, 'video/mp4')}
                        data = {'camera_id': str(args.camera_id)}
                        resp = requests.post(args.ingest_url, files=files, data=data, timeout=60)
                        dur = time.time() - start
                        print(f"[{ts}] upload {filename} ({grabbed}f/{args.seconds}s) -> {resp.status_code}: {resp.text[:120]} (took {dur:.1f}s)")
                except requests.RequestException as e:
                    print(f"[{ts}] upload error: {e}")
                finally:
                    try:
                        os.remove(temp_path)
                    except OSError:
                        pass
    except KeyboardInterrupt:
        print('\nStop by user.')
    finally:
        cap.release()
        cv2.destroyAllWindows()


if __name__ == '__main__':
    main()
