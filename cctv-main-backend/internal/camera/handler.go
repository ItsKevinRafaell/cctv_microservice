package camera

import (
	"cctv-main-backend/internal/domain"
	"cctv-main-backend/pkg/auth"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/golang-jwt/jwt/v5"
)

type Handler struct {
	service Service
}

func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) CreateCamera(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
	if !ok {
		http.Error(w, "Gagal mengambil data pengguna dari token", http.StatusInternalServerError)
		return
	}

	companyID, _ := claims["company_id"].(float64)

	var camera domain.Camera
	if err := json.NewDecoder(r.Body).Decode(&camera); err != nil {
		http.Error(w, "Request body tidak valid", http.StatusBadRequest)
		return
	}

	camera.CompanyID = int64(companyID)

	cameraID, err := h.service.RegisterCamera(&camera)
	if err != nil {
		http.Error(w, "Gagal mendaftarkan kamera", http.StatusInternalServerError)
		return
	}

	response := map[string]int64{"camera_id": cameraID}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(response)
}

func (h *Handler) GetCameras(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
	if !ok {
		http.Error(w, "Gagal mengambil data pengguna dari token", http.StatusInternalServerError)
		return
	}
	companyID, _ := claims["company_id"].(float64)

	cameras, err := h.service.GetCamerasForCompany(int64(companyID))
	if err != nil {
		http.Error(w, "Gagal mengambil data kamera", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(cameras)
}

func (h *Handler) UpdateCamera(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(r.URL.Path, "/")
	id, _ := strconv.ParseInt(parts[len(parts)-1], 10, 64)

	claims, _ := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
	companyID, _ := claims["company_id"].(float64)

	var camera domain.Camera
	if err := json.NewDecoder(r.Body).Decode(&camera); err != nil {
		http.Error(w, "Request body tidak valid", http.StatusBadRequest)
		return
	}

	camera.ID = id
	camera.CompanyID = int64(companyID)

	if err := h.service.UpdateCamera(&camera); err != nil {
		http.Error(w, "Gagal memperbarui kamera", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Kamera berhasil diperbarui."))
}

func (h *Handler) DeleteCamera(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(r.URL.Path, "/")
	id, _ := strconv.ParseInt(parts[len(parts)-1], 10, 64)

	claims, _ := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
	companyID, _ := claims["company_id"].(float64)

	if err := h.service.DeleteCamera(id, int64(companyID)); err != nil {
		http.Error(w, "Gagal menghapus kamera", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Kamera berhasil dihapus."))
}
