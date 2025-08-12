# core/processor.py
import os
os.environ.setdefault("KERAS_BACKEND", "tensorflow")  # pastikan Keras 3 pakai backend TF

import keras
import cv2
import numpy as np
from collections import deque
from typing import Optional, Tuple
from services.reporting_service import ReportingService


class VideoProcessor:
    """
    Video anomaly inference from a saved Keras (v3) model (.h5) on video clips.
    Expects the model to output probs in order: [anomaly, normal].
    """

    def __init__(self, reporting_service: ReportingService, model_path: str):
        # Model/input config — sesuaikan dengan config training
        self.image_height: int = 64
        self.image_width: int = 64
        self.sequence_length: int = 50

        # Inference window stride (lebih hemat compute daripada setiap frame)
        self.window_stride: int = 5  # geser 5 frame per evaluasi; ubah sesuai kebutuhan

        # Services + model
        self.reporting_service = reporting_service
        self.model_path = model_path
        self.model: Optional[keras.Model] = None

        # Load model
        self._load_model()

    # -------------------------
    # Setup / load
    # -------------------------
    def _load_model(self) -> None:
        print(f"[*] Memuat model dari {self.model_path}...")
        print("PWD:", os.getcwd(), "Exists(mod.h5)?", os.path.exists(self.model_path))
        try:
            # Keras 3 loader (cocok dengan keras_version=3.x di H5)
            self.model = keras.saving.load_model(self.model_path, compile=False)
            # Warmup opsional (mengecek shape)
            _dummy = np.zeros(
                (1, self.sequence_length, self.image_height, self.image_width, 3),
                dtype=np.float32,
            )
            try:
                _ = self.model.predict(_dummy, verbose=0)
            except Exception:
                pass
            print("✅ Model berhasil dimuat.")
        except Exception as e:
            print(f"❌ Gagal memuat model: {e}")
            # Raise supaya container fail fast jika model invalid
            raise

    # -------------------------
    # Public API
    # -------------------------
    def analyze(self, task: dict) -> None:
        """
        task:
          - video_path (str): path file video di volume /app/uploads
          - video_url  (str): URL publik (untuk dikirim ke backend)
          - original_filename (str, optional): untuk debug
        """
        video_path = task.get("video_path")
        video_url = task.get("video_url")
        original_filename = task.get("original_filename", "")

        # Validasi path
        if not video_path or not os.path.exists(video_path):
            print("[!] 'video_path' tidak ada/invalid:", video_path)
            return

        print(f" [->] Memulai analisis klip: {original_filename or os.path.basename(video_path)}")
        print(f"     Path: {video_path}")

        # Fallback "force anomaly" via nama file (untuk debug cepat)
        if "anomaly" in (original_filename or "").lower():
            print(" [!] Anomali terdeteksi (DIPAKSA via nama file).")
            self.reporting_service.send_report(0.99, video_url)
            return

        if self.model is None:
            print("[!] Model belum termuat. Lewati analisis.")
            return

        # Jalankan infer dari klip
        score = self._infer_from_video(video_path)

        if score is None:
            print("[-] Video terlalu pendek — tidak ada window penuh untuk inferensi.")
            return

        print(f"[✓] Skor anomali (max): {score:.3f}")
        self.reporting_service.send_report(float(score), video_url)

    # -------------------------
    # Core inference
    # -------------------------
    def _infer_from_video(self, video_path: str) -> Optional[float]:
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            print("[!] Gagal membuka video:", video_path)
            return None

        frames = deque(maxlen=self.sequence_length)
        anomaly_scores: list[float] = []

        # Counter untuk stride
        since_last_eval = 0

        try:
            while True:
                ok, frame = cap.read()
                if not ok:
                    break

                img = self._preprocess_frame(frame)
                frames.append(img)

                if len(frames) == self.sequence_length:
                    if since_last_eval == 0:
                        # Prediksi pada window lengkap
                        seq = np.expand_dims(np.array(frames, dtype=np.float32), axis=0)  # (1, T, H, W, 3)
                        preds = self.model.predict(seq, verbose=0)

                        # Ekspektasi output: (1, 2) = [anomali, normal]
                        if preds.ndim == 2 and preds.shape[1] >= 2:
                            anomaly_prob = float(preds[0][0])
                        else:
                            # fallback kalau model output 1 neuron (sigmoid), treat as anomaly prob
                            anomaly_prob = float(preds[0][0])

                        anomaly_scores.append(anomaly_prob)

                        # Geser window manual (lebih efisien dari evaluasi per frame)
                        self._slide_window(frames, self.window_stride)

                        # Reset stride counter
                        since_last_eval = 0
                    else:
                        since_last_eval = (since_last_eval + 1) % self.window_stride
                # else: kumpulkan dulu sampai penuh
        finally:
            cap.release()

        if not anomaly_scores:
            return None

        # Agregasi skor: max (bisa diganti mean/percentile tergantung strategi)
        return float(max(anomaly_scores))

    # -------------------------
    # Utils
    # -------------------------
    def _preprocess_frame(self, frame: np.ndarray) -> np.ndarray:
        """Resize + normalize ke [0,1]."""
        img = cv2.resize(frame, (self.image_width, self.image_height))
        img = img.astype(np.float32) / 255.0
        return img

    @staticmethod
    def _slide_window(frames: deque, stride: int) -> None:
        """Geser window fixed-size deque sebanyak 'stride' frame."""
        for _ in range(max(1, stride)):
            if frames:
                frames.popleft()
            else:
                break
