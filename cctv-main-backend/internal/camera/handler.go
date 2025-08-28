package camera

import (
    "cctv-main-backend/internal/domain"
    "cctv-main-backend/pkg/auth"
    "encoding/json"
    "errors"
    "net/http"
    "strconv"
    "strings"

    "github.com/golang-jwt/jwt/v5"
    "os"
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
    role, _ := claims["role"].(string)

    var camera domain.Camera
    if err := json.NewDecoder(r.Body).Decode(&camera); err != nil {
        http.Error(w, "Request body tidak valid", http.StatusBadRequest)
        return
    }

    // superadmin can specify target company_id in request body
    if role == "superadmin" && camera.CompanyID != 0 {
        // use provided
    } else {
        camera.CompanyID = int64(companyID)
    }

    cameraID, err := h.service.RegisterCamera(&camera)
    if err != nil {
        if errors.Is(err, ErrStreamKeyConflict) {
            http.Error(w, "stream_key sudah digunakan", http.StatusConflict)
            return
        }
        http.Error(w, "Gagal mendaftarkan kamera", http.StatusInternalServerError)
        return
    }

    // Build streaming URLs based on env + stream_key
    sk := camera.StreamKey
    if sk == "" { // default sk cam<id>
        sk = "cam" + strconv.FormatInt(cameraID, 10)
    }
    resp := map[string]any{
        "camera_id":  cameraID,
        "stream_key": sk,
        "hls_url":    buildHLSURL(sk),
        "rtsp_url":   buildRTSPURL(sk),
        "webrtc_url": buildWebRTCURL(sk),
    }
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    _ = json.NewEncoder(w).Encode(resp)
}

func (h *Handler) GetCameras(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
	if !ok {
		http.Error(w, "Gagal mengambil data pengguna dari token", http.StatusInternalServerError)
		return
	}
    companyID, _ := claims["company_id"].(float64)
    role, _ := claims["role"].(string)
    if role == "superadmin" {
        if v := r.URL.Query().Get("company_id"); v != "" {
            if id, err := strconv.ParseInt(v, 10, 64); err == nil {
                companyID = float64(id)
            }
        }
    }

    cameras, err := h.service.GetCamerasForCompany(int64(companyID))
    if err != nil {
        http.Error(w, "Gagal mengambil data kamera", http.StatusInternalServerError)
        return
    }

    type CameraResp struct {
        ID         int64  `json:"id"`
        Name       string `json:"name"`
        Location   string `json:"location,omitempty"`
        StreamKey  string `json:"stream_key,omitempty"`
        HLSURL     string `json:"hls_url,omitempty"`
        RTSPURL    string `json:"rtsp_url,omitempty"`
        WebRTCURL  string `json:"webrtc_url,omitempty"`
    }
    out := make([]CameraResp, 0)
    for _, c := range cameras {
        sk := c.StreamKey
        if sk == "" {
            sk = "cam" + strconv.FormatInt(c.ID, 10)
        }
        out = append(out, CameraResp{
            ID:        c.ID,
            Name:      c.Name,
            Location:  c.Location,
            StreamKey: sk,
            HLSURL:    buildHLSURL(sk),
            RTSPURL:   buildRTSPURL(sk),
            WebRTCURL: buildWebRTCURL(sk),
        })
    }
    w.Header().Set("Content-Type", "application/json")
    _ = json.NewEncoder(w).Encode(out)
}

func (h *Handler) UpdateCamera(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(r.URL.Path, "/")
	id, _ := strconv.ParseInt(parts[len(parts)-1], 10, 64)

    claims, _ := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
    companyID, _ := claims["company_id"].(float64)
    role, _ := claims["role"].(string)

    var camera domain.Camera
    if err := json.NewDecoder(r.Body).Decode(&camera); err != nil {
        http.Error(w, "Request body tidak valid", http.StatusBadRequest)
        return
    }

    camera.ID = id
    if role == "superadmin" {
        if err := h.service.UpdateCameraAdmin(&camera); err != nil {
            if errors.Is(err, ErrStreamKeyConflict) {
                http.Error(w, "stream_key sudah digunakan", http.StatusConflict)
                return
            }
            http.Error(w, "Gagal memperbarui kamera", http.StatusInternalServerError)
            return
        }
    } else {
        camera.CompanyID = int64(companyID)
        if err := h.service.UpdateCamera(&camera); err != nil {
            if errors.Is(err, ErrStreamKeyConflict) {
                http.Error(w, "stream_key sudah digunakan", http.StatusConflict)
                return
            }
            http.Error(w, "Gagal memperbarui kamera", http.StatusInternalServerError)
            return
        }
    }
    w.WriteHeader(http.StatusOK)
    w.Write([]byte("Kamera berhasil diperbarui."))
}

func (h *Handler) DeleteCamera(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(r.URL.Path, "/")
	id, _ := strconv.ParseInt(parts[len(parts)-1], 10, 64)

    claims, _ := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
    role, _ := claims["role"].(string)

    if role == "superadmin" {
        if err := h.service.DeleteCameraAdmin(id); err != nil {
            http.Error(w, "Gagal menghapus kamera", http.StatusInternalServerError)
            return
        }
    } else {
        companyID, _ := claims["company_id"].(float64)
        if err := h.service.DeleteCamera(id, int64(companyID)); err != nil {
            http.Error(w, "Gagal menghapus kamera", http.StatusInternalServerError)
            return
        }
    }
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Kamera berhasil dihapus."))
}

// Utilities to build stream URLs from env.
func env(k, def string) string {
    if v := os.Getenv(k); v != "" { return v }
    return def
}

func buildHLSURL(streamKey string) string {
    host := env("MEDIAMTX_PUBLIC_HOST", "127.0.0.1")
    port := env("MEDIAMTX_PUBLIC_HLS_PORT", "8888")
    scheme := env("MEDIAMTX_PUBLIC_HLS_SCHEME", "http")
    return scheme + "://" + host + ":" + port + "/" + streamKey + "/index.m3u8"
}
func buildRTSPURL(streamKey string) string {
    host := env("MEDIAMTX_PUBLIC_HOST", "127.0.0.1")
    port := env("MEDIAMTX_PUBLIC_RTSP_PORT", "8554")
    return "rtsp://" + host + ":" + port + "/" + streamKey
}
func buildWebRTCURL(streamKey string) string {
    host := env("MEDIAMTX_PUBLIC_HOST", "127.0.0.1")
    port := env("MEDIAMTX_PUBLIC_WEBRTC_WS_PORT", "8889")
    scheme := env("MEDIAMTX_PUBLIC_WEBRTC_SCHEME", "ws")
    return scheme + "://" + host + ":" + port + "/" + streamKey
}
