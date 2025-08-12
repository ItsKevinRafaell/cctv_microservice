import os
os.environ.setdefault("KERAS_BACKEND", "tensorflow")  # pastikan Keras 3 pakai backend TF

import keras
import cv2
import numpy as np
from collections import deque
from typing import Optional
from services.reporting_service import ReportingService

class VideoProcessor:
    """
    Video anomaly inference dari model Keras (v3) .h5 pada klip video.
    Ekspektasi output model: probs [anomaly, normal] (shape (1,2)).
    """

    def __init__(self, reporting_service: ReportingService, model_path: str):
        # Konfigurasi input — sesuaikan dengan training
        self.image_height = 64
        self.image_width = 64
        self.sequence_length = 50

        # Evaluasi tiap N frame (hemat compute)
        self.window_stride = int(os.getenv("WINDOW_STRIDE", "5"))

        # Threshold kirim alert
        self.threshold = float(os.getenv("ANOMALY_THRESHOLD", "0.80"))

        self.reporting_service = reporting_service
        self.model_path = model_path
        self.model: Optional[keras.Model] = None

        self._load_model()

    # -------------------------
    # Load model
    # -------------------------
    def _load_model(self) -> None:
        print(f"[*] Memuat model dari {self.model_path}...")
        print("PWD:", os.getcwd(), "Exists(mod.h5)?", os.path.exists(self.model_path))
        try:
            self.model = keras.saving.load_model(self.model_path, compile=False)
            # Warmup cek shape
            _ = self.model.predict(
                np.zeros((1, self.sequence_length, self.image_height, self.image_width, 3), dtype=np.float32),
                verbose=0
            )
            print("✅ Model berhasil dimuat.")
        except Exception as e:
            print(f"❌ Gagal memuat model: {e}")
            # Fail fast supaya container restart
            raise

    # -------------------------
    # Public API
    # -------------------------
    def analyze(self, task: dict) -> None:
        """
        task:
          - video_path (str): path file (di volume /app/uploads)
          - video_url  (str): URL publik (untuk laporan)
          - original_filename (str, optional)
          - camera_id (str|int, optional; default 1)
        """
        video_path = task.get("video_path")
        video_url  = task.get("video_url")
        original_filename = task.get("original_filename", "")
        camera_id = int(task.get("camera_id") or 1)

        if not video_path or not os.path.exists(video_path):
            print("[!] 'video_path' tidak ada/invalid:", video_path)
            return

        print(f" [->] Analisis: {original_filename or os.path.basename(video_path)}")
        print(f"     Path: {video_path} | CameraID: {camera_id} | Threshold: {self.threshold:.2f} | Stride: {self.window_stride}")

        # Debug: force anomaly via nama file
        if "anomaly" in (original_filename or "").lower():
            print(" [!] Anomali terdeteksi (DIPAKSA via nama file).")
            ok = self.reporting_service.send_report(camera_id, 0.99, video_url, anomaly_type="forced_anomaly")
            if not ok:
                raise RuntimeError("Kirim report gagal (forced_anomaly).")
            return

        if self.model is None:
            print("[!] Model belum termuat. Skip.")
            return

        score = self._infer_from_video(video_path)
        if score is None:
            print("[-] Video terlalu pendek — tidak ada window penuh.")
            return

        print(f"[✓] Skor anomali (max): {score:.3f}")
        if score >= self.threshold:
            ok = self.reporting_service.send_report(camera_id, float(score), video_url, anomaly_type="model_detected")
            if not ok:
                raise RuntimeError("Kirim report gagal setelah retry.")
        else:
            print(f"[-] Skor < threshold ({self.threshold:.2f}); tidak mengirim laporan.")

    # -------------------------
    # Core inference
    # -------------------------
    def _infer_from_video(self, video_path: str) -> Optional[float]:
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            print("[!] Gagal membuka video:", video_path)
            return None

        frames = deque(maxlen=self.sequence_length)
        scores = []

        try:
            while True:
                ok, frame = cap.read()
                if not ok:
                    break

                img = self._preprocess_frame(frame)
                frames.append(img)

                if len(frames) == self.sequence_length:
                    seq = np.expand_dims(np.array(frames, dtype=np.float32), axis=0)  # (1,T,H,W,3)
                    preds = self.model.predict(seq, verbose=0)

                    # Ekspektasi (1,2) => [anomaly, normal]; fallback kalau 1 neuron
                    anomaly_prob = None
                    try:
                        if preds.ndim == 2 and preds.shape[1] >= 2:
                            anomaly_prob = float(preds[0][0])
                        else:
                            anomaly_prob = float(preds[0][0])
                    except Exception:
                        anomaly_prob = float(np.ravel(preds)[0])

                    scores.append(anomaly_prob)

                    # Geser window untuk evaluasi berikutnya
                    self._slide_window(frames, self.window_stride)
        finally:
            cap.release()

        if not scores:
            return None
        return float(max(scores))

    # -------------------------
    # Utils
    # -------------------------
    def _preprocess_frame(self, frame: np.ndarray) -> np.ndarray:
        # Catatan: OpenCV BGR; sesuaikan dengan pipeline training kamu
        img = cv2.resize(frame, (self.image_width, self.image_height))
        img = img.astype(np.float32) / 255.0
        return img

    @staticmethod
    def _slide_window(frames: deque, stride: int) -> None:
        for _ in range(max(1, stride)):
            if frames:
                frames.popleft()
            else:
                break
