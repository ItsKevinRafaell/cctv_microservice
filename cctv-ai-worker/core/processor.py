# core/processor.py
import os
os.environ.setdefault("KERAS_BACKEND", "tensorflow")

import keras
import cv2
import numpy as np
from collections import deque
from typing import Optional, List
from services.reporting_service import ReportingService

class VideoProcessor:
    """
    Inference anomali sesuai training:
    - ambil tepat 50 frame TERSEBAR MERATA (uniform sampling) dari seluruh video
    - resize 64x64, /255, BGR (tanpa konversi RGB)
    - output softmax [anomaly(0), normal(1)] → ANOMALY_CLASS_INDEX=0
    """

    def __init__(self, reporting_service: ReportingService, model_path: str):
        # Konfigurasi input (match training)
        self.image_height = 64
        self.image_width = 64
        self.sequence_length = 50

        # Tuning via ENV
        self.threshold = float(os.getenv("ANOMALY_THRESHOLD", "0.95"))          # ambang alert
        self.anom_idx = int(os.getenv("ANOMALY_CLASS_INDEX", "0"))              # 0 = anomaly (sesuai training)
        self.infer_mode = os.getenv("INFER_MODE", "uniform").strip().lower()    # "uniform" | "sliding"
        # Opsi untuk SLIDING (opsional; tidak dipakai di uniform)
        self.window_stride = int(os.getenv("WINDOW_STRIDE", "5"))
        self.aggregator = os.getenv("AGGREGATOR", "mean").strip().lower()       # "mean" | "max"
        self.consecutive = int(os.getenv("CONSECUTIVE_WINDOWS", "0"))
        self.convert_rgb = os.getenv("CONVERT_BGR2RGB", "false").lower() == "true"  # training: false
        self.debug_pred = os.getenv("DEBUG_PRED", "false").lower() == "true"

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
            # Warmup shape
            _ = self.model.predict(
                np.zeros((1, self.sequence_length, self.image_height, self.image_width, 3), dtype=np.float32),
                verbose=0
            )
            print("✅ Model berhasil dimuat.")
        except Exception as e:
            print(f"❌ Gagal memuat model: {e}")
            raise

    # -------------------------
    # Public API
    # -------------------------
    def analyze(self, task: dict) -> None:
        video_path = task.get("video_path")
        video_url  = task.get("video_url")
        original_filename = task.get("original_filename", "")
        camera_id = int(task.get("camera_id") or 1)

        if not video_path or not os.path.exists(video_path):
            print("[!] 'video_path' tidak ada/invalid:", video_path)
            return

        print(f" [->] Analisis: {original_filename or os.path.basename(video_path)}")
        print(f"     Path: {video_path} | CameraID: {camera_id} | Mode: {self.infer_mode} | "
              f"Thres: {self.threshold:.2f} | anom_idx: {self.anom_idx} | RGB: {self.convert_rgb}")

        # Debug paksa anomaly via nama file
        if "anomaly" in (original_filename or "").lower():
            print(" [!] Anomali (FORCED by filename).")
            ok = self.reporting_service.send_report(camera_id, 0.99, video_url, anomaly_type="forced_anomaly")
            if not ok:
                raise RuntimeError("Kirim report gagal (forced_anomaly).")
            return

        if self.model is None:
            print("[!] Model belum termuat. Skip.")
            return

        # ---- INFERENCE ----
        if self.infer_mode == "uniform":
            score = self._uniform_sample_predict(video_path)  # satu skor untuk seluruh klip
            if score is None:
                print("[-] Video terlalu pendek/tidak cukup frame untuk uniform sampling.")
                return

            print(f"[✓] Skor anomali (uniform-50): {score:.3f}")
            if score >= self.threshold:
                ok = self.reporting_service.send_report(camera_id, float(score), video_url, anomaly_type="model_detected")
                if not ok:
                    raise RuntimeError("Kirim report gagal.")
            else:
                print(f"[-] Skor < threshold ({self.threshold:.2f}); tidak kirim laporan.")
            return

        # ---- fallback: SLIDING (opsional) ----
        scores = self._scores_from_video(video_path)
        if not scores:
            print("[-] Video terlalu pendek — tidak ada window penuh.")
            return
        if self.consecutive >= 2:
            consec = 0; peak = 0.0
            for p in scores:
                if p >= self.threshold:
                    consec += 1; peak = max(peak, p)
                    if consec >= self.consecutive:
                        print(f"[✓] Trigger by {self.consecutive} consecutive windows, peak={peak:.3f}")
                        ok = self.reporting_service.send_report(camera_id, float(peak), video_url, anomaly_type="model_detected")
                        if not ok:
                            raise RuntimeError("Kirim report gagal (consecutive).")
                        return
                else:
                    consec = 0; peak = 0.0
            print(f"[-] Tidak ada {self.consecutive} window berturut di atas threshold.")
            return
        agg = float(np.max(scores) if self.aggregator == "max" else np.mean(scores))
        print(f"[✓] Skor anomali (sliding-{self.aggregator}): {agg:.3f}")
        if agg >= self.threshold:
            ok = self.reporting_service.send_report(camera_id, float(agg), video_url, anomaly_type="model_detected")
            if not ok:
                raise RuntimeError("Kirim report gagal.")
        else:
            print(f"[-] Skor < threshold ({self.threshold:.2f}); tidak kirim laporan.")

    # -------------------------
    # Uniform 50-frame sampling (match training)
    # -------------------------
    def _uniform_sample_predict(self, video_path: str) -> Optional[float]:
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            print("[!] Gagal membuka video:", video_path)
            return None

        try:
            total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            if total <= 0:
                # fallback hitung manual
                total = 0
                while True:
                    ok, _ = cap.read()
                    if not ok: break
                    total += 1
                cap.release()
                cap = cv2.VideoCapture(video_path)
                if total <= 0:
                    return None

            skip = max(int(total / self.sequence_length), 1)
            frames: List[np.ndarray] = []

            for i in range(self.sequence_length):
                cap.set(cv2.CAP_PROP_POS_FRAMES, i * skip)
                ok, frame = cap.read()
                if not ok:
                    break
                frames.append(self._preprocess_frame(frame))

            if len(frames) != self.sequence_length:
                return None

            seq = np.expand_dims(np.array(frames, dtype=np.float32), axis=0)  # (1,50,64,64,3)
            preds = self.model.predict(seq, verbose=0)

            if self.debug_pred:
                try:
                    vec = preds[0].tolist()
                    print("DEBUG preds:", [round(float(x), 3) for x in vec])
                except Exception:
                    pass

            try:
                anomaly_prob = float(preds[0][self.anom_idx])
            except Exception:
                anomaly_prob = float(np.ravel(preds)[0])
            return anomaly_prob
        finally:
            cap.release()

    # -------------------------
    # Sliding mode (opsional)
    # -------------------------
    def _scores_from_video(self, video_path: str) -> Optional[List[float]]:
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            print("[!] Gagal membuka video:", video_path)
            return None

        from collections import deque
        frames = deque(maxlen=self.sequence_length)
        scores: List[float] = []
        debug_count = 0

        try:
            stride_counter = 0
            while True:
                ok, frame = cap.read()
                if not ok:
                    break
                frames.append(self._preprocess_frame(frame))
                if len(frames) == self.sequence_length:
                    if stride_counter == 0:
                        seq = np.expand_dims(np.array(frames, dtype=np.float32), axis=0)
                        preds = self.model.predict(seq, verbose=0)
                        try:
                            p = float(preds[0][self.anom_idx])
                        except Exception:
                            p = float(np.ravel(preds)[0])
                        scores.append(p)
                        if self.debug_pred and debug_count < 3:
                            try:
                                vec = preds[0].tolist()
                                print("DEBUG preds:", [round(float(x), 3) for x in vec])
                            except Exception:
                                pass
                            debug_count += 1
                        self._slide_window(frames, self.window_stride)
                        stride_counter = 0
                    else:
                        stride_counter = (stride_counter + 1) % max(1, self.window_stride)
        finally:
            cap.release()
        return scores

    # -------------------------
    # Utils
    # -------------------------
    def _preprocess_frame(self, frame: np.ndarray) -> np.ndarray:
        if self.convert_rgb:
            frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)  # training = false
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
