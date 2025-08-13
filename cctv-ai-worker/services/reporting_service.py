# services/reporting_service.py
import time
import requests

class ReportingService:
    def __init__(self, base_url, timeout=10, max_retries=3):
        self.url = f"{base_url}/api/report-anomaly"
        self.timeout = timeout
        self.max_retries = max_retries

    def send_report(self, camera_id: int, confidence_score: float, video_url: str,
                    anomaly_type: str = "model_detected") -> bool:
        payload = {
            'camera_id': int(camera_id),
            'anomaly_type': anomaly_type or 'model_detected',
            'confidence': round(float(confidence_score), 4),
            'video_clip_url': video_url or "",
        }
        print(f" [->] Mengirim laporan ke Backend Utama: {payload}")

        for attempt in range(1, self.max_retries + 1):
            try:
                resp = requests.post(self.url, json=payload, timeout=self.timeout)
                if resp.status_code == 200:
                    print(" [✔] Laporan berhasil dikirim.")
                    return True
                else:
                    print(f" [!] Gagal kirim (attempt {attempt}/{self.max_retries}) "
                          f"status={resp.status_code} msg={resp.text}")
            except requests.exceptions.RequestException as e:
                print(f" [!] Error saat menghubungi Backend (attempt {attempt}/{self.max_retries}): {e}")
            time.sleep(min(2 ** attempt, 8))  # 2s,4s,8s
        return False
