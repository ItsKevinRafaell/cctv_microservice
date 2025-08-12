package user

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

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	var input domain.User
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		http.Error(w, "Request body tidak valid", http.StatusBadRequest)
		return
	}

	token, err := h.service.Login(&input)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	response := map[string]string{"token": token}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (h *Handler) Register(w http.ResponseWriter, r *http.Request) {
	var user domain.User
	if err := json.NewDecoder(r.Body).Decode(&user); err != nil {
		http.Error(w, "Request body tidak valid", http.StatusBadRequest)
		return
	}

	if user.Role == "" {
		user.Role = "user"
	}

	err := h.service.Register(&user)
	if err != nil {
		http.Error(w, "Email sudah terdaftar atau terjadi kesalahan lain", http.StatusConflict)
		return
	}

	w.WriteHeader(http.StatusCreated)
	w.Write([]byte("User berhasil didaftarkan untuk perusahaan terkait."))
}

func (h *Handler) GetAllUsers(w http.ResponseWriter, r *http.Request) {
	claims, _ := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
	companyID, _ := claims["company_id"].(float64)

	users, err := h.service.FindUsersByCompany(int64(companyID))
	if err != nil {
		http.Error(w, "Gagal mengambil data pengguna", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(users)
}

func (h *Handler) UpdateUserRole(w http.ResponseWriter, r *http.Request) {
	claims, _ := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
	companyID, _ := claims["company_id"].(float64)
	role, _ := claims["role"].(string)

	if role != "company_admin" {
		http.Error(w, "Anda tidak punya izin untuk melakukan aksi ini", http.StatusForbidden)
		return
	}

	parts := strings.Split(r.URL.Path, "/")
	userID, _ := strconv.ParseInt(parts[len(parts)-1], 10, 64)

	var reqBody map[string]string
	if err := json.NewDecoder(r.Body).Decode(&reqBody); err != nil {
		http.Error(w, "Request body tidak valid", http.StatusBadRequest)
		return
	}
	newRole := reqBody["role"]

	if err := h.service.UpdateRole(userID, int64(companyID), newRole); err != nil {
		http.Error(w, "Pengguna tidak ditemukan atau bukan bagian dari perusahaan Anda", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Peran pengguna berhasil diperbarui."))
}

func (h *Handler) DeleteUser(w http.ResponseWriter, r *http.Request) {
	claims, _ := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
	companyID, _ := claims["company_id"].(float64)
	role, _ := claims["role"].(string)

	if role != "company_admin" {
		http.Error(w, "Anda tidak punya izin untuk melakukan aksi ini", http.StatusForbidden)
		return
	}

	parts := strings.Split(r.URL.Path, "/")
	userID, _ := strconv.ParseInt(parts[len(parts)-1], 10, 64)

	if err := h.service.Delete(userID, int64(companyID)); err != nil {
		http.Error(w, "Pengguna tidak ditemukan atau bukan bagian dari perusahaan Anda", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Pengguna berhasil dihapus."))
}
