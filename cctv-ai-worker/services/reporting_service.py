import requests

class ReportingService:
    def __init__(self, base_url: str):
        self.url = f"{base_url}/api/report-anomaly"

    def send_report(self, camera_id: int, anomaly_type: str, confidence_score: float, video_url: str):
        payload = {
            "camera_id": int(camera_id),
            "anomaly_type": anomaly_type,
            "confidence": round(float(confidence_score), 4),
            "video_clip_url": video_url,
        }
        print(f" [->] Mengirim laporan ke Backend Utama: {payload}")
        try:
            r = requests.post(self.url, json=payload, timeout=10)
            if r.status_code == 200:
                print(" [✔] Laporan berhasil dikirim.")
            else:
                print(f" [!] Gagal kirim laporan. Status: {r.status_code}, Pesan: {r.text}")
        except requests.exceptions.RequestException as e:
            print(f" [!] Error HTTP ke Backend Utama: {e}")
