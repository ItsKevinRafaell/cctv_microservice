"""Webcam preview and clip uploader.

Example:
  python cctv-camera/send_webcam_clips.py --camera-id 3 --seconds 10 --fps 15
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
    p.add_argument('--force-anomaly', action='store_true', default=os.getenv('FORCE_ANOMALY', 'false').lower() == 'true')
    return p.parse_args()


def main():
    args = parse_args()
    frame_size = (args.width, args.height)
    n_frames = int(args.seconds * args.fps)

    cap = cv2.VideoCapture(0, cv2.CAP_DSHOW) if hasattr(cv2, 'CAP_DSHOW') else cv2.VideoCapture(0)
    if not cap.isOpened():
        raise RuntimeError('Tidak bisa membuka webcam (index 0).')

    cap.set(cv2.CAP_PROP_FPS, args.fps)
    fourccs = [cv2.VideoWriter_fourcc(*'mp4v'), cv2.VideoWriter_fourcc(*'XVID')]

    print(f"Preview ON -> {args.seconds}s/clip @ {args.fps} FPS, upload to {args.ingest_url}, camera_id={args.camera_id}")
    try:
        while True:
            ts = dt.datetime.now().strftime('%Y%m%d-%H%M%S')
            suffix = '-anomaly' if args.force_anomaly else ''
            filename = f"{ts}{suffix}.mp4"
            temp_path = os.path.join(tempfile.gettempdir(), filename)

            writer = None
            for fourcc in fourccs:
                writer = cv2.VideoWriter(temp_path, fourcc, args.fps, frame_size)
                if writer.isOpened():
                    break
            if writer is None or not writer.isOpened():
                raise RuntimeError('Gagal membuka VideoWriter. Coba turunkan resolusi/FPS.')

            grabbed = 0
            start = time.time()
            while grabbed < n_frames:
                ok, frame = cap.read()
                if not ok:
                    break
                frame = cv2.resize(frame, frame_size)
                writer.write(frame)
                grabbed += 1

                # Preview
                disp = frame.copy()
                cv2.putText(disp, f"REC {grabbed}/{n_frames}", (10, 24), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
                cv2.putText(disp, 'q: quit', (10, frame_size[1] - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)
                cv2.imshow('Webcam -> Ingestion', disp)
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

