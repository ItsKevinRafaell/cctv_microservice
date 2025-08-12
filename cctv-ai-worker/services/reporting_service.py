import requests

class ReportingService:
    def __init__(self, base_url):
        self.url = f"{base_url}/api/report-anomaly"

    def send_report(self, confidence_score: float, video_url: str):
        report_payload = {
            'camera_id': 1,
            'anomaly_type': 'forced_anomaly',
            'confidence': round(confidence_score, 4),
            'video_clip_url': video_url,
        }
        
        print(f" [->] Mengirim laporan ke Backend Utama: {report_payload}")
        try:
            response = requests.post(self.url, json=report_payload, timeout=10)
            if response.status_code == 200:
                print(" [✔] Laporan berhasil dikirim.")
            else:
                print(f" [!] Gagal mengirim laporan. Status: {response.status_code}, Pesan: {response.text}")
        except requests.exceptions.RequestException as e:
            print(f" [!] Terjadi kesalahan saat menghubungi Backend Utama: {e}")