# core/processor.py
import os
from collections import deque
from pathlib import Path
from typing import Optional

import cv2
import numpy as np
import torch

from core.models import load_model
from services.reporting_service import ReportingService
from datetime import datetime
import json

def _env_bool(name: str, default: bool=False) -> bool:
    v = os.getenv(name, None)
    return default if v is None else str(v).lower() in ("1","true","yes","y","on")

def _ensure_dir(p: str):
    os.makedirs(p, exist_ok=True)
    return p

class VideoProcessor:
    """
    Inference anomali sesuai training:
    - ambil 50 frame yang tersebar merata (uniform) atau jendela geser (sliding)
    - ekstrak 106 fitur statistik per frame + normalisasi standar (opsional)
    - output probabilitas [normal(0), anomaly(1)] dengan default ANOMALY_CLASS_INDEX=1
    """

    def __init__(self, reporting_service: ReportingService, model_path: str):
        # Konfigurasi input (match training)
        self.image_height = 64
        self.image_width = 64
        self.sequence_length = 50
        self.feature_dim = 106

        # Tuning via ENV
        self.threshold = float(os.getenv("ANOMALY_THRESHOLD", "0.65"))          # ambang alert
        self.anom_idx = int(os.getenv("ANOMALY_CLASS_INDEX", "1"))              # default 1: probs=[normal, anomaly]
        self.infer_mode = os.getenv("INFER_MODE", "uniform").strip().lower()    # "uniform" | "sliding"
        # Opsi untuk SLIDING (opsional; tidak dipakai di uniform)
        self.window_stride = int(os.getenv("WINDOW_STRIDE", "5"))
        self.aggregator = os.getenv("AGGREGATOR", "mean").strip().lower()       # "mean" | "max"
        self.consecutive = int(os.getenv("CONSECUTIVE_WINDOWS", "0"))
        self.convert_rgb = os.getenv("CONVERT_BGR2RGB", "false").lower() == "true"  # training: false
        self.debug_pred = os.getenv("DEBUG_PRED", "false").lower() == "true"

        self.reporting_service = reporting_service
        self.model_path = model_path
        self.model: Optional[torch.nn.Module] = None

        default_scaler = Path(__file__).resolve().parent.parent / "_scaler.npz"
        scaler_path = Path(os.getenv("FEATURE_SCALER_PATH", str(default_scaler)))
        self.scaler_mean: Optional[np.ndarray] = None
        self.scaler_std: Optional[np.ndarray] = None
        if scaler_path.exists():
            try:
                data = np.load(scaler_path)
                self.scaler_mean = data["mean"].astype(np.float32)
                self.scaler_std = data["std"].astype(np.float32)
                if self.scaler_mean.shape[0] == self.scaler_std.shape[0]:
                    self.feature_dim = int(self.scaler_mean.shape[0])
                    self.scaler_std = np.where(self.scaler_std < 1e-6, 1.0, self.scaler_std)
                else:
                    self.scaler_mean = self.scaler_std = None
            except Exception as exc:
                print(f"[!] Gagal memuat scaler fitur ({scaler_path}): {exc}")
                self.scaler_mean = self.scaler_std = None
        else:
            print(f"[!] File scaler fitur tidak ditemukan di {scaler_path}, menggunakan fitur mentah.")

        self._load_model()

    # -------------------------
    # Load model
    # -------------------------
    def _load_model(self) -> None:
        print(f"[*] Memuat model PyTorch dari {self.model_path}...")
        device = "cuda" if torch.cuda.is_available() else "cpu"
        try:
            self.model = load_model(self.model_path, device=device)
            self.device = device
            # warmup menggunakan fitur dummy
            dummy = torch.zeros(
                (1, self.sequence_length, self.feature_dim),
                dtype=torch.float32,
                device=device,
            )
            with torch.no_grad():
                _ = self.model(dummy)
            print(f"[OK] Model berhasil dimuat ke {device}.")
        except Exception as e:
            print(f"[ERROR] Gagal memuat model: {e}")
            raise


    def _preprocess_frame(self, frame: np.ndarray) -> np.ndarray:
        frame = cv2.resize(frame, (self.image_width, self.image_height))
        if self.convert_rgb:
            frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        return frame.astype(np.float32) / 255.0

    def _extract_features(self, frame: np.ndarray) -> np.ndarray:
        hist_bins = 32
        feats = []
        for channel in range(3):
            hist = cv2.calcHist([frame], [channel], None, [hist_bins], [0.0, 1.0])
            hist = cv2.normalize(hist, hist).flatten()
            feats.append(hist)
        feats = np.concatenate(feats)  # 96 dim

        channel_mean = frame.mean(axis=(0, 1))
        channel_std = frame.std(axis=(0, 1))
        frame_u8 = np.clip(frame * 255.0, 0, 255).astype(np.uint8)
        gray = cv2.cvtColor(frame_u8, cv2.COLOR_BGR2GRAY)
        gray_mean = gray.mean() / 255.0
        gray_std = gray.std() / 255.0
        edges = cv2.Canny(frame_u8, 100, 200)
        edge_density = float(np.count_nonzero(edges)) / edges.size
        lap_var = cv2.Laplacian(gray, cv2.CV_32F).var() / (255.0 ** 2)

        extra = np.array(
            [
                channel_mean[0],
                channel_mean[1],
                channel_mean[2],
                channel_std[0],
                channel_std[1],
                channel_std[2],
                gray_mean,
                gray_std,
                edge_density,
                lap_var,
            ],
            dtype=np.float32,
        )
        feats = np.concatenate([feats, extra]).astype(np.float32)
        if feats.shape[0] != self.feature_dim:
            # Pad or truncate to expected dim to avoid runtime failure
            if feats.shape[0] < self.feature_dim:
                feats = np.pad(feats, (0, self.feature_dim - feats.shape[0]), mode="constant")
            else:
                feats = feats[: self.feature_dim]
        return feats

    def _scale_features(self, feats: np.ndarray) -> np.ndarray:
        if self.scaler_mean is None or self.scaler_std is None:
            return feats
        return (feats - self.scaler_mean) / self.scaler_std


    # -------------------------
    # Public API
    # -------------------------
    def analyze(self, task: dict) -> None:
        video_path = task.get("video_path")
        video_url  = task.get("video_url")
        original_filename = task.get("original_filename", "")
        camera_id = int(task.get("camera_id", 0) or 0)

        # Jika path lokal tidak tersedia, coba unduh dari URL presign
        downloaded_tmp = None
        try:
            if (not video_path or not os.path.exists(video_path)) and video_url:
                try:
                    import tempfile, requests, shutil
                    tmp_dir = _ensure_dir("/app/uploads/tmp")
                    suffix = os.path.splitext(original_filename or "clip.mp4")[1] or ".mp4"
                    fd, tmp_path = tempfile.mkstemp(prefix="dl_", suffix=suffix, dir=tmp_dir)
                    os.close(fd)
                    print(f"[->] Mengunduh video dari presigned URL ke: {tmp_path}")
                    with requests.get(video_url, stream=True, timeout=60) as r:
                        r.raise_for_status()
                        with open(tmp_path, 'wb') as f:
                            shutil.copyfileobj(r.raw, f)
                    video_path = tmp_path
                    downloaded_tmp = tmp_path
                except Exception as e:
                    print(f"[!] Gagal mengunduh dari presigned URL: {e}")

            if not video_path or not os.path.exists(video_path):
                print("[!] 'video_path' tidak ada/invalid:", video_path)
                return

            infer_mode = os.getenv("INFER_MODE", "uniform").lower()     # uniform | sliding
            anomaly_idx = int(os.getenv("ANOMALY_CLASS_INDEX", "0"))
            thr = float(os.getenv("ANOMALY_THRESHOLD", "0.65"))
            min_gap = float(os.getenv("ANOMALY_MIN_GAP", "0.00"))
            stride = int(os.getenv("WINDOW_STRIDE", "5"))
            consec = int(os.getenv("CONSECUTIVE_WINDOWS", "1"))
            agg = os.getenv("AGGREGATOR", "mean").lower()
            debug_pred = _env_bool("DEBUG_PRED", False)
            dbg_json = _env_bool("DEBUG_SAVE_JSON", True)
            dbg_video = _env_bool("DEBUG_SAVE_OVERLAY", False)

            basename = original_filename or os.path.basename(video_path)
            debug_root = _ensure_dir(f"/app/uploads/debug/{os.path.splitext(basename)[0]}")
            debug_json_path = os.path.join(debug_root, "debug.json")
            debug_vid_path = os.path.join(debug_root, "overlay.mp4")

            print(f"\n [->] Analisis: {basename}")
            print(f"     Path: {video_path} | CameraID: {camera_id} | Mode: {infer_mode} | Thr: {thr:.2f}")

            # Smoke-test: paksa anomali via nama file
            if _env_bool("FORCE_ANOMALY_BY_FILENAME", False) and "anomaly" in basename.lower():
                print(" [!] Anomali (FORCED by filename).")
                self.reporting_service.send_report(
                    camera_id=camera_id,
                    anomaly_type="forced_by_filename",
                    confidence_score=0.99,
                    video_url=video_url,
                )
                return

            # Kumpulkan info dasar video
            cap0 = cv2.VideoCapture(video_path)
            fps = float(cap0.get(cv2.CAP_PROP_FPS) or 0.0)
            total_frames = int(cap0.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
            width = int(cap0.get(cv2.CAP_PROP_FRAME_WIDTH) or 0)
            height = int(cap0.get(cv2.CAP_PROP_FRAME_HEIGHT) or 0)
            cap0.release()
            duration = (total_frames / fps) if fps > 0 else 0.0
            print(f"     Meta: {total_frames} frames @ {fps:.2f} fps (~{duration:.2f}s), {width}x{height}")

            # Infer
            if infer_mode == "uniform":
                score, pair, dbg = self._infer_uniform_like_training(video_path, anomaly_idx, debug_pred)
            else:
                score, pair, dbg = self._infer_sliding(video_path, anomaly_idx, stride, agg, consec, debug_pred)

            if score is None:
                print("[-] Tidak ada skor (video terlalu pendek?).")
                return

            p_anom, p_norm = pair
            gap = p_anom - p_norm
            is_anom = (p_anom >= thr) and (gap >= min_gap)

            print(f"[SCORE] p_anom={p_anom:.3f} p_norm={p_norm:.3f} gap={gap:.3f} -> {'ANOMALY' if is_anom else 'normal'}")

            # Simpan debug JSON
            if dbg_json:
                out = {
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                    "file": basename,
                    "video_path": video_path,
                    "meta": {
                        "fps": fps,
                        "total_frames": total_frames,
                        "duration_sec": duration,
                        "width": width,
                        "height": height,
                    },
                    "infer": {
                        "mode": infer_mode,
                        "threshold": thr,
                        "min_gap": min_gap,
                        "anomaly_class_index": anomaly_idx,
                        "stride": stride,
                        "aggregator": agg,
                        "consecutive_windows": consec,
                    },
                    "result": {
                        "p_anom": p_anom,
                        "p_norm": p_norm,
                        "gap": gap,
                        "decision": "anomaly" if is_anom else "normal",
                    },
                    "details": dbg,  # indeks sample (uniform) / skor per window (sliding)
                    "video_url": video_url,
                    "camera_id": camera_id,
                }
                try:
                    with open(debug_json_path, "w") as f:
                        json.dump(out, f, indent=2)
                    print(f"   [DEBUG] Debug JSON: {debug_json_path}")
                except Exception as e:
                    print("   [!] Gagal tulis debug JSON:", e)

            # (opsional) simpan video overlay
            if dbg_video:
                try:
                    self._save_overlay_video(video_path, debug_vid_path, p_anom, is_anom, thr)
                    print(f"   [DEBUG] Overlay MP4: {debug_vid_path}")
                except Exception as e:
                    print("   [!] Gagal render overlay:", e)

            # Kirim report hanya kalau anomali (atau aktifkan REPORT_NORMAL_AS_INFO)
            if is_anom:
                self.reporting_service.send_report(
                    camera_id=camera_id,
                    anomaly_type="model_detected",
                    confidence_score=float(p_anom),
                    video_url=video_url,
                )
            elif _env_bool("REPORT_NORMAL_AS_INFO", False):
                self.reporting_service.send_report(
                    camera_id=camera_id,
                    anomaly_type="normal_observed",
                    confidence_score=float(1.0 - p_anom),
                    video_url=video_url,
                )
            else:
                print("[-] Normal -> tidak kirim laporan.")
        finally:
            if downloaded_tmp and os.path.exists(downloaded_tmp):
                try:
                    os.remove(downloaded_tmp)
                except OSError as cleanup_err:
                    print(f"[!] Gagal menghapus file sementara: {cleanup_err}")

    def _infer_uniform_like_training(self, video_path: str, anomaly_idx: int, debug: bool):
        T = self.sequence_length
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            return None, (0.0, 0.0), {}

        total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
        if total <= 0:
            cap.release()
            return None, (0.0, 0.0), {}

        skip = max(total // T, 1)
        idxs, features = [], []
        for i in range(T):
            idx = i * skip
            cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
            ok, frame = cap.read()
            if not ok:
                break
            frame = self._preprocess_frame(frame)
            feats = self._scale_features(self._extract_features(frame))
            features.append(feats)
            idxs.append(int(idx))
        cap.release()

        if len(features) < T:
            return None, (0.0, 0.0), {"sampled_indices": idxs, "note": "insufficient frames"}

        seq = np.expand_dims(np.array(features, dtype=np.float32), axis=0)  # (1,50,feature_dim)
        with torch.no_grad():
            tensor = torch.from_numpy(seq).float().to(self.device)
            preds = self.model(tensor).cpu().numpy()
        if debug:
            print("DEBUG preds(uniform):", preds[0].tolist())

        p_anom = float(preds[0][anomaly_idx])
        p_norm = float(preds[0][1 - anomaly_idx]) if preds.shape[1] > 1 else 1.0 - p_anom
        dbg = {"sampled_indices": idxs, "pred_vector": preds[0].tolist()}
        return p_anom, (p_anom, p_norm), dbg


    # --- Sliding window (rata2 / max) ---
    def _infer_sliding(self, video_path: str, anomaly_idx: int, stride: int, agg: str, consec: int, debug: bool):
        T = self.sequence_length
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            return None, (0.0, 0.0), {}

        feature_queue: deque[np.ndarray] = deque(maxlen=T)
        win = 0
        scores, frames_idx = [], []  # list of (p_anom, p_norm)
        k = 0
        try:
            while True:
                ok, frame = cap.read()
                if not ok: break
                frame = self._preprocess_frame(frame)
                feats = self._scale_features(self._extract_features(frame))
                feature_queue.append(feats)
                if len(feature_queue) == T:
                    if k % max(1, stride) == 0:
                        seq = np.expand_dims(np.array(feature_queue, dtype=np.float32), axis=0)
                        with torch.no_grad():
                            tensor = torch.from_numpy(seq).float().to(self.device)
                            preds = self.model(tensor).cpu().numpy()
                        pa = float(preds[0][anomaly_idx])
                        pn = float(preds[0][1 - anomaly_idx]) if preds.shape[1] > 1 else 1.0 - pa
                        scores.append((pa, pn))
                        frames_idx.append(int(k))
                        win += 1
                        if debug: print(f"DEBUG preds(win {win} @ {k}):", preds[0].tolist())
                k += 1
        finally:
            cap.release()

        if not scores:
            return None, (0.0, 0.0), {}

        p_anoms = [s[0] for s in scores]
        p_norms = [s[1] for s in scores]
        if agg == "max":
            p_anom = max(p_anoms); p_norm = p_norms[p_anoms.index(p_anom)]
        elif agg == "p90":
            p_anom = float(np.percentile(p_anoms, 90)); p_norm = 1.0 - p_anom
        else:
            p_anom = float(np.mean(p_anoms)); p_norm = float(np.mean(p_norms))

        # optional: streak
        if consec > 1:
            thr = float(os.getenv("ANOMALY_THRESHOLD","0.65"))
            streak = 0
            ok_streak = False
            for pa,_ in scores:
                streak = streak + 1 if pa >= thr else 0
                if streak >= consec:
                    ok_streak = True; break
            # kalau butuh strict streak, bisa override agregasi:
            # if not ok_streak: return p_anom, (p_anom, p_norm), {"windows": scores, "indices": frames_idx, "note": "no streak"}
        dbg = {"windows": scores, "indices": frames_idx, "aggregated": {"mode": agg, "p_anom": p_anom, "p_norm": p_norm}}
        return p_anom, (p_anom, p_norm), dbg
    
    def _save_overlay_video(self, src_path: str, out_path: str, p_anom: float, is_anom: bool, thr: float):
        cap = cv2.VideoCapture(src_path)
        if not cap.isOpened(): return
        w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH) or 640)
        h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT) or 360)
        fps = cap.get(cv2.CAP_PROP_FPS) or 25.0

        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out = cv2.VideoWriter(out_path, fourcc, fps, (w, h))
        color = (0,0,255) if is_anom else (0,255,0)
        label = f"{'ANOMALY' if is_anom else 'Normal'} | p={p_anom:.2f} thr={thr:.2f}"

        while True:
            ok, frame = cap.read()
            if not ok: break
            cv2.rectangle(frame, (0,0), (w, 40), (0,0,0), -1)
            cv2.putText(frame, label, (10,28), cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2, cv2.LINE_AA)
            out.write(frame)

        out.release()
        cap.release()
