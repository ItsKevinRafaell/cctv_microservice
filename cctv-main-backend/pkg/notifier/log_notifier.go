package notifier

import (
	"cctv-main-backend/internal/domain"
	"log"
)

// Notifier adalah interface untuk semua jenis pengirim notifikasi.
type Notifier interface {
	Send(report *domain.AnomalyReport) error
}

// LogNotifier adalah implementasi Notifier yang hanya mencetak ke log.
type LogNotifier struct{}

func NewLogNotifier() *LogNotifier {
	return &LogNotifier{}
}

// Send mensimulasikan pengiriman notifikasi dengan mencetak ke konsol.
func (n *LogNotifier) Send(report *domain.AnomalyReport) error {
	log.Println("--- 🚀 SIMULASI NOTIFIKASI PUSH ---")
	log.Printf("  > Mengirim ke pengguna yang terkait dengan Kamera ID: %d", report.CameraID)
	log.Printf("  > Judul: Anomali Terdeteksi!")
	log.Printf("  > Isi: Terdeteksi '%s' dengan kepercayaan %.2f%%", report.AnomalyType, report.Confidence*100)
	log.Println("------------------------------------")
	return nil
}
