package user

import (
    "bytes"
    "cctv-main-backend/internal/domain"
    "cctv-main-backend/pkg/auth"
    "encoding/json"
    "errors"
    "io"
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
    // Be robust: try JSON, if fails, try form fields
    body, _ := io.ReadAll(r.Body)
    r.Body.Close()
    r.Body = io.NopCloser(bytes.NewReader(body))
    if err := json.NewDecoder(r.Body).Decode(&input); err != nil || input.Email == "" || input.Password == "" {
        // Fallback to form
        // Reset body just in case other middlewares expect it (not necessary here)
        _ = r.ParseForm()
        email := r.FormValue("email")
        password := r.FormValue("password")
        if email == "" || password == "" {
            http.Error(w, "Request body tidak valid", http.StatusBadRequest)
            return
        }
        input.Email = email
        input.Password = password
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
    body, _ := io.ReadAll(r.Body)
    r.Body.Close()
    r.Body = io.NopCloser(bytes.NewReader(body))
    if err := json.NewDecoder(r.Body).Decode(&user); err != nil || user.Email == "" || (user.Password == "" && user.PasswordHash == "") {
        // Fallback to form
        _ = r.ParseForm()
        email := r.FormValue("email")
        password := r.FormValue("password")
        if email == "" || password == "" {
            http.Error(w, "Request body tidak valid", http.StatusBadRequest)
            return
        }
        user.Email = email
        user.Password = password
        if cid := r.FormValue("company_id"); cid != "" {
            if v, err := strconv.ParseInt(cid, 10, 64); err == nil {
                user.CompanyID = v
            }
        }
        if role := r.FormValue("role"); role != "" {
            user.Role = role
        }
    }

    // Normalize email
    user.Email = strings.ToLower(strings.TrimSpace(user.Email))
    // Default role if not provided
    if user.Role == "" {
        user.Role = "user"
    }

    // Enforce company scoping for non-superadmin: use company_id from JWT
    if claims, ok := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims); ok {
        if role, _ := claims["role"].(string); role != "superadmin" {
            if cid, ok2 := claims["company_id"].(float64); ok2 {
                user.CompanyID = int64(cid)
            }
        }
    }

	if user.Role == "" {
		user.Role = "user"
	}

    err := h.service.Register(&user)
    if err != nil {
        // Map duplicate email to 409, others 500
        if errors.Is(err, ErrEmailTaken) {
            http.Error(w, "Email sudah terdaftar", http.StatusConflict)
            return
        }
        http.Error(w, "Terjadi kesalahan saat membuat user", http.StatusInternalServerError)
        return
    }

	w.WriteHeader(http.StatusCreated)
	w.Write([]byte("User berhasil didaftarkan untuk perusahaan terkait."))
}

func (h *Handler) GetAllUsers(w http.ResponseWriter, r *http.Request) {
    claims, _ := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
    role, _ := claims["role"].(string)

    // Superadmin: allow optional ?company_id= to filter, otherwise list all users
    if role == "superadmin" {
        if v := r.URL.Query().Get("company_id"); v != "" {
            if id, err := strconv.ParseInt(v, 10, 64); err == nil {
                users, err := h.service.FindUsersByCompany(id)
                if err != nil { http.Error(w, "Gagal mengambil data pengguna", http.StatusInternalServerError); return }
                w.Header().Set("Content-Type", "application/json")
                _ = json.NewEncoder(w).Encode(users)
                return
            }
        }
        users, err := h.service.FindAllUsers()
        if err != nil { http.Error(w, "Gagal mengambil data pengguna", http.StatusInternalServerError); return }
        w.Header().Set("Content-Type", "application/json")
        _ = json.NewEncoder(w).Encode(users)
        return
    }

    // Non-superadmin: list only users in own company
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
