package ingest

import (
	"log"
	"net/http"
	"strconv" // NEW
)

type Handler struct {
	service Service
}

func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) VideoIngestHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Metode tidak diizinkan", http.StatusMethodNotAllowed)
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, 50*1024*1024)
	if err := r.ParseMultipartForm(50 * 1024 * 1024); err != nil {
		http.Error(w, "File terlalu besar", http.StatusBadRequest)
		return
	}

	file, handler, err := r.FormFile("video_clip")
	if err != nil {
		http.Error(w, "Gagal membaca file dari request", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// NEW: baca camera_id dari form
	cameraIDStr := r.FormValue("camera_id")
	if cameraIDStr == "" {
		http.Error(w, "camera_id wajib diisi (multipart form field)", http.StatusBadRequest)
		return
	}
	if _, err := strconv.Atoi(cameraIDStr); err != nil {
		http.Error(w, "camera_id harus angka", http.StatusBadRequest)
		return
	}

	log.Printf("✅ Menerima file: %s, Ukuran: %d bytes, camera_id=%s\n", handler.Filename, handler.Size, cameraIDStr)

	// NEW: teruskan cameraIDStr ke service
	if err := h.service.ProcessVideo(file, handler, cameraIDStr); err != nil {
		log.Printf("❌ Gagal memproses video: %v\n", err)
		http.Error(w, "Gagal memproses file", http.StatusInternalServerError)
		return
	}

	log.Println("   > File berhasil diproses dan tugas analisis dikirim.")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("File berhasil diunggah dan dijadwalkan untuk analisis."))
}
