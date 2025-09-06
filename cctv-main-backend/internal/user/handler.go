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

    // Ambil role dan company dari JWT (endpoint ini sekarang protected)
    claims, _ := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
    callerRole, _ := claims["role"].(string)
    callerCompanyID, _ := claims["company_id"].(float64)

    // Validasi peran pembuat
    switch callerRole {
    case "superadmin":
        // superadmin: jika tidak memilih company_id, hanya boleh membuat superadmin global (company_id NULL)
        if user.CompanyID == 0 {
            if user.Role == "" { user.Role = "superadmin" }
            if user.Role != "superadmin" {
                http.Error(w, "Tanpa company, hanya boleh membuat superadmin", http.StatusBadRequest)
                return
            }
        } else {
            if user.Role == "" { user.Role = "user" }
        }
    case "company_admin":
        // company_admin hanya boleh membuat role 'user' di perusahaannya sendiri
        user.Role = "user"
        user.CompanyID = int64(callerCompanyID)
    default:
        http.Error(w, "Anda tidak punya izin untuk melakukan aksi ini", http.StatusForbidden)
        return
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
    role, _ := claims["role"].(string)
    if role == "superadmin" {
        if v := r.URL.Query().Get("company_id"); v != "" {
            if id, err := strconv.ParseInt(v, 10, 64); err == nil {
                companyID = float64(id)
            }
        }
    }

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

    if role != "company_admin" && role != "superadmin" {
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
    newEmail := reqBody["email"]
    newPassword := reqBody["password"]
    newName := reqBody["name"]
    // superadmin dapat override company_id via body
    if role == "superadmin" {
        if s, ok := reqBody["company_id"]; ok && s != "" {
            if id, err := strconv.ParseInt(s, 10, 64); err == nil {
                companyID = float64(id)
            }
        }
    }

    // Guard: company_admin tidak boleh demote admin menjadi user
    if role == "company_admin" && newRole == "user" {
        currentRole, err := h.service.GetUserRole(userID, int64(companyID))
        if err != nil {
            http.Error(w, "Pengguna tidak ditemukan atau bukan bagian dari perusahaan Anda", http.StatusNotFound)
            return
        }
        if currentRole == "company_admin" {
            http.Error(w, "company_admin tidak boleh menurunkan admin menjadi user", http.StatusForbidden)
            return
        }
    }
    // Apply updates selectively
    if newRole != "" {
        if err := h.service.UpdateRole(userID, int64(companyID), newRole); err != nil {
            http.Error(w, "Pengguna tidak ditemukan atau bukan bagian dari perusahaan Anda", http.StatusNotFound)
            return
        }
    }
    if newEmail != "" {
        if err := h.service.UpdateEmail(userID, int64(companyID), newEmail); err != nil {
            http.Error(w, "Gagal memperbarui email", http.StatusBadRequest)
            return
        }
    }
    if newPassword != "" {
        if err := h.service.UpdatePassword(userID, int64(companyID), newPassword); err != nil {
            http.Error(w, "Gagal memperbarui password", http.StatusBadRequest)
            return
        }
    }
    if newName != "" {
        if err := h.service.UpdateName(userID, int64(companyID), newName); err != nil {
            http.Error(w, "Gagal memperbarui nama", http.StatusBadRequest)
            return
        }
    }
    w.WriteHeader(http.StatusOK)
    w.Write([]byte("Pengguna berhasil diperbarui."))
}

func (h *Handler) DeleteUser(w http.ResponseWriter, r *http.Request) {
    claims, _ := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
    companyID, _ := claims["company_id"].(float64)
    role, _ := claims["role"].(string)

    if role != "company_admin" && role != "superadmin" {
        http.Error(w, "Anda tidak punya izin untuk melakukan aksi ini", http.StatusForbidden)
        return
    }

    parts := strings.Split(r.URL.Path, "/")
    userID, _ := strconv.ParseInt(parts[len(parts)-1], 10, 64)
    // superadmin dapat override company_id via query
    if role == "superadmin" {
        if v := r.URL.Query().Get("company_id"); v != "" {
            if id, err := strconv.ParseInt(v, 10, 64); err == nil {
                companyID = float64(id)
            }
        }
    }

	if err := h.service.Delete(userID, int64(companyID)); err != nil {
		http.Error(w, "Pengguna tidak ditemukan atau bukan bagian dari perusahaan Anda", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Pengguna berhasil dihapus."))
}

func (h *Handler) UpdateFCMToken(w http.ResponseWriter, r *http.Request) {
	// Ambil ID pengguna dari token JWT yang sudah divalidasi
	claims, _ := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
	userID, _ := claims["user_id"].(float64)

	// Baca fcm_token dari body request
	var payload struct {
		FCMToken string `json:"fcm_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "Request body tidak valid", http.StatusBadRequest)
		return
	}

	// Panggil service untuk menyimpan token
	err := h.service.SaveFCMToken(int64(userID), payload.FCMToken)
	if err != nil {
		http.Error(w, "Gagal menyimpan token FCM", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Token FCM berhasil diperbarui."))
}
