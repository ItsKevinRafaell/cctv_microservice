package anomaly

import (
	"cctv-main-backend/internal/domain"
	"cctv-main-backend/pkg/auth"
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"github.com/golang-jwt/jwt/v5"
)

type Handler struct {
	service Service
}

type ContextKey string

const UserClaimsKey = ContextKey("userClaims")

func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) CreateReport(w http.ResponseWriter, r *http.Request) {
	var report domain.AnomalyReport
	if err := json.NewDecoder(r.Body).Decode(&report); err != nil {
		http.Error(w, "Request body tidak valid", http.StatusBadRequest)
		return
	}

	if report.CameraID == 0 {
		http.Error(w, "camera_id wajib diisi", http.StatusBadRequest)
		return
	}

	log.Printf("✅ Laporan Diterima dari Kamera ID: %d, Tipe: %s", report.CameraID, report.AnomalyType)

	err := h.service.SaveReport(&report)
	if err != nil {
		log.Printf("❌ `Gagal memproses laporan: %v", err)
		http.Error(w, "Gagal memproses laporan", http.StatusInternalServerError)
		return
	}

	log.Println("   > Laporan berhasil disimpan.")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Laporan berhasil diterima dan disimpan."))
}

func (h *Handler) GetAllReports(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
	if !ok || claims == nil {
		http.Error(w, "Gagal mengambil data pengguna dari token", http.StatusUnauthorized)
		fmt.Println("Failed to get claims from context.")
		return
	}

	fmt.Println("Claims in GetAllReports:", claims)

	companyID, ok := claims["company_id"].(float64)
	if !ok {
		http.Error(w, "Gagal mengambil company_id dari token", http.StatusUnauthorized)
		fmt.Println("Failed to extract company_id from claims.")
		return
	}

	reports, err := h.service.FetchAllReportsByCompany(int64(companyID))
	if err != nil {
		http.Error(w, "Gagal mengambil data", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(reports)
}
