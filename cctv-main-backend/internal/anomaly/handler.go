package anomaly

import (
    "cctv-main-backend/internal/domain"
    "cctv-main-backend/pkg/auth"
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "strconv"
    "time"
    "net/url"
    "path"
    "strings"

    "github.com/golang-jwt/jwt/v5"
    "os"
)

type Handler struct {
    service Service
    // optional S3 presigner for detail endpoint
    s3         s3Presigner
    clipBucket string
}

type ContextKey string

const UserClaimsKey = ContextKey("userClaims")

// minimal interface needed from S3Util
type s3Presigner interface {
    Presign(bucket, key string, ttl time.Duration) (string, error)
}

func NewHandler(service Service, s3 s3Presigner, clipBucket string) *Handler {
    return &Handler{service: service, s3: s3, clipBucket: clipBucket}
}

func (h *Handler) CreateReport(w http.ResponseWriter, r *http.Request) {
    // Optional shared secret untuk membatasi akses endpoint internal
    if sec := os.Getenv("WORKER_SHARED_TOKEN"); sec != "" {
        if r.Header.Get("X-Worker-Token") != sec {
            http.Error(w, "Unauthorized", http.StatusUnauthorized)
            return
        }
    }
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

func (h *Handler) GetRecent(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
	if !ok || claims == nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	companyID, ok := claims["company_id"].(float64)
	if !ok {
		http.Error(w, "Invalid token claims", http.StatusUnauthorized)
		return
	}

	limit := 20
	if s := r.URL.Query().Get("limit"); s != "" {
		if v, err := strconv.Atoi(s); err == nil {
			limit = v
		}
	}
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}

	reports, err := h.service.ListRecent(int64(companyID), limit)
	if err != nil {
		http.Error(w, "Gagal mengambil data", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(reports)
}

// GET /api/anomalies/{id}
func (h *Handler) GetDetail(w http.ResponseWriter, r *http.Request) {
    claims, ok := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
    if !ok || claims == nil { http.Error(w, "Unauthorized", http.StatusUnauthorized); return }
    companyID, ok := claims["company_id"].(float64)
    if !ok { http.Error(w, "Invalid token claims", http.StatusUnauthorized); return }

    parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
    if len(parts) < 3 { http.Error(w, "bad path", http.StatusBadRequest); return }
    id, err := strconv.ParseInt(parts[2], 10, 64)
    if err != nil { http.Error(w, "bad id", http.StatusBadRequest); return }

    rep, err := h.service.GetDetail(int64(companyID), id)
    if err != nil { http.Error(w, "not found", http.StatusNotFound); return }

    clipURL := rep.VideoClipURL
    if h.s3 != nil && clipURL != "" {
        if bkt, key, ok := parseBucketKey(clipURL); ok {
            if bkt == "" { bkt = h.clipBucket }
            if url, err := h.s3.Presign(bkt, key, 10*time.Minute); err == nil {
                clipURL = url
            }
        }
    }

    w.Header().Set("Content-Type", "application/json")
    _ = json.NewEncoder(w).Encode(map[string]any{
        "id": rep.ID,
        "camera_id": rep.CameraID,
        "anomaly_type": rep.AnomalyType,
        "confidence": rep.Confidence,
        "reported_at": rep.ReportedAt,
        "video_clip_url": clipURL,
    })
}

func parseBucketKey(u string) (bucket string, key string, ok bool) {
    p, err := url.Parse(u)
    if err != nil { return "","", false }
    seg := strings.Split(strings.Trim(p.Path, "/"), "/")
    if len(seg) < 2 { return "","", false }
    bucket = seg[0]
    key = path.Clean(strings.Join(seg[1:], "/"))
    return bucket, key, true
}
