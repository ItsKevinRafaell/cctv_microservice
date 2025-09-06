package main

import (
	"cctv-main-backend/internal/anomaly"
	"cctv-main-backend/internal/camera"
	"cctv-main-backend/internal/company"
	"cctv-main-backend/internal/domain"
	"cctv-main-backend/internal/handlers"
	"cctv-main-backend/internal/storage"
	"cctv-main-backend/internal/user"
	"cctv-main-backend/pkg/auth"
	"cctv-main-backend/pkg/database"
	"cctv-main-backend/pkg/notifier"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"runtime"
	"strings"
	"time"

    "golang.org/x/crypto/bcrypt"
	"github.com/golang-jwt/jwt/v5"
)

func main() {
	db := database.NewConnection()
	database.Migrate(db)
	defer db.Close()

	// Seed optional superadmin if env provided
	ensureSuperadmin(db)

	mux := http.NewServeMux()

	// repos
	anomalyRepo := anomaly.NewRepository(db)
	userRepo := user.NewRepository(db)
	companyRepo := company.NewRepository(db)
	cameraRepo := camera.NewRepository(db)

	// notifier: jika ada PUSH_SERVICE_URL gunakan HTTPNotifier, kalau tidak fallback FCM/log
	var n notifier.Notifier
	if base := os.Getenv("PUSH_SERVICE_URL"); base != "" {
		secret := os.Getenv("PUSH_SERVICE_SECRET")
		httpN, err := notifier.NewHTTPNotifierWithSecret(base, secret)
		if err != nil {
			log.Println("HTTPNotifier init error, fallback ke FCM/log:", err)
		} else {
			httpN.GetAdminTokens = userRepo.GetFCMTokensByCompanyAllRoles
			httpN.GetCompanyIDByCameraID = cameraRepo.GetCompanyIDByCameraID
			n = httpN
			log.Println("Notifier: HTTP push-service")
		}
	}
	if n == nil {
		if cred := os.Getenv("FIREBASE_CREDENTIALS"); cred != "" {
			fcm, err := notifier.NewFCM(context.Background(), cred)
			if err != nil {
				log.Println("FCM init error, fallback ke log:", err)
				n = notifier.NewLogNotifier()
			} else {
				fcm.GetAdminTokens = userRepo.GetFCMTokensByCompanyAllRoles
				fcm.GetCompanyIDByCameraID = cameraRepo.GetCompanyIDByCameraID
				fcm.DeleteToken = userRepo.DeleteFCMTokenByValue
				fcm.UseTopic = false
				fcm.TopicPrefix = "alerts"
				n = fcm
				log.Println("Notifier: FCM (direct-to-token)")
			}
		} else {
			n = notifier.NewLogNotifier()
			log.Println("Notifier: LOG (fallback)")
		}
	}

	minioInternal := getEnv("MINIO_INTERNAL_ENDPOINT", "http://minio:9000")
	minioPublic := getEnv("MINIO_PUBLIC_ENDPOINT", "http://127.0.0.1:9000")
	access := getEnv("MINIO_ACCESS_KEY", "minioadmin")
	secret := getEnv("MINIO_SECRET_KEY", "minio-secret-key")
	publicBase := getEnv("MINIO_PUBLIC_BASE_URL", "http://127.0.0.1:9000")
	usePresign := getEnv("MINIO_USE_PRESIGN", "true") == "true"
	bucketArchive := getEnv("ARCHIVE_BUCKET", "video-archive")

	s3u, err := storage.NewS3Util(minioInternal, minioPublic, access, secret, publicBase, usePresign, 24*time.Hour)
	if err != nil {
		log.Fatalf("init S3Util: %v", err)
	}
	if err := s3u.EnsureBucket(context.Background(), bucketArchive); err != nil {
		log.Printf("ensure bucket %s: %v", bucketArchive, err)
	}
	recHandler := handlers.NewRecordingHandler(db, s3u, bucketArchive)
	clipsBucket := getEnv("MINIO_BUCKET", "video-clips")

	// services + handlers
	anomalyService := anomaly.NewService(anomalyRepo, n)
	anomalyHandler := anomaly.NewHandler(anomalyService, s3u, clipsBucket)

	userService := user.NewService(userRepo)
	userHandler := user.NewHandler(userService)

	companyService := company.NewService(companyRepo)
	companyHandler := company.NewHandler(companyService)

	cameraService := camera.NewService(cameraRepo)
	cameraHandler := camera.NewHandler(cameraService)

	// routes (sama seperti punyamu)
	// Protect register: only authenticated callers can create users (enforced per-role in handler)
	mux.HandleFunc("/api/register", authMiddleware(userHandler.Register))
	mux.HandleFunc("/api/login", userHandler.Login)
	mux.HandleFunc("/api/users", authMiddleware(userHandler.GetAllUsers))
	mux.HandleFunc("/api/users/fcm-token", authMiddleware(userHandler.UpdateFCMToken))
	mux.HandleFunc("/api/users/", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodPut:
			userHandler.UpdateUserRole(w, r)
		case http.MethodDelete:
			userHandler.DeleteUser(w, r)
		default:
			http.Error(w, "Metode tidak diizinkan", http.StatusMethodNotAllowed)
		}
	}))

	mux.HandleFunc("/api/report-anomaly", anomalyHandler.CreateReport)
	mux.HandleFunc("/api/anomalies", authMiddleware(anomalyHandler.GetAllReports))
	mux.HandleFunc("/api/anomalies/", authMiddleware(anomalyHandler.GetDetail))
	mux.HandleFunc("/api/anomalies/recent", authMiddleware(anomalyHandler.GetRecent))

	mux.HandleFunc("/api/companies", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodPost:
			RequireRole("superadmin", companyHandler.CreateCompany)(w, r)
		case http.MethodGet:
			RequireRole("superadmin", companyHandler.GetAllCompanies)(w, r)
		default:
			http.Error(w, "Metode tidak diizinkan", http.StatusMethodNotAllowed)
		}
	}))

	mux.HandleFunc("/api/companies/", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodPut:
			RequireRole("superadmin", companyHandler.UpdateCompany)(w, r)
		case http.MethodDelete:
			RequireRole("superadmin", companyHandler.DeleteCompany)(w, r)
		default:
			http.Error(w, "Metode tidak diizinkan", http.StatusMethodNotAllowed)
		}
	}))

	mux.HandleFunc("/api/cameras/", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		// /api/cameras/{id}/recordings  → GET daftar rekaman
		if strings.HasSuffix(r.URL.Path, "/recordings") {
			if r.Method != http.MethodGet {
				http.Error(w, "Method not allowed for recordings", http.StatusMethodNotAllowed)
				return
			}
			recHandler.ListRecordings(w, r) // handler yang kita buat sebelumnya
			return
		}

		// /api/cameras/{id} → update/hapus kamera
		switch r.Method {
		case http.MethodPut:
			cameraHandler.UpdateCamera(w, r)
		case http.MethodDelete:
			cameraHandler.DeleteCamera(w, r)
		default:
			http.Error(w, "Metode tidak diizinkan di rute ini", http.StatusMethodNotAllowed)
		}
	}))

	mux.HandleFunc("/api/cameras", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodPost:
			cameraHandler.CreateCamera(w, r)
		case http.MethodGet:
			cameraHandler.GetCameras(w, r)
		default:
			http.Error(w, "Metode tidak diizinkan", http.StatusMethodNotAllowed)
		}
	}))

	// Test notification endpoint: send push for given anomaly_id or latest anomaly in company
    mux.HandleFunc("/api/notifications/test", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Metode tidak diizinkan", http.StatusMethodNotAllowed)
			return
		}
		if n == nil {
			http.Error(w, "Notifier tidak tersedia", http.StatusServiceUnavailable)
			return
		}
		claims, ok := r.Context().Value(auth.UserClaimsKey).(jwt.MapClaims)
		if !ok || claims == nil {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		var companyID int64
		role, _ := claims["role"].(string)
		if strings.EqualFold(role, "superadmin") {
			companyID = 0
		} else {
			cID, ok := claims["company_id"].(float64)
			if !ok {
				http.Error(w, "Invalid token claims", http.StatusUnauthorized)
				return
			}
			companyID = int64(cID)
		}
		var payload struct{
			AnomalyID int64 `json:"anomaly_id"`
		}
		_ = json.NewDecoder(r.Body).Decode(&payload)
        var rep *domain.AnomalyReport
        if payload.AnomalyID > 0 {
            if x, err := anomalyService.GetDetail(companyID, payload.AnomalyID); err == nil {
                rep = x
            } else {
                http.Error(w, "Anomali tidak ditemukan", http.StatusNotFound)
                return
            }
        } else {
            if list, err := anomalyService.ListRecent(companyID, 1); err == nil && len(list) > 0 {
                rep = &list[0]
            }
            if rep == nil {
                http.Error(w, "Tidak ada anomaly untuk perusahaan ini", http.StatusBadRequest)
                return
            }
        }
        if rep.AnomalyType == "" {
            rep.AnomalyType = "anomaly"
        }
        // Debug: tentukan target company berdasarkan camera id
        targetCompanyID := companyID
        if rep.CameraID > 0 {
            if cid, err := cameraRepo.GetCompanyIDByCameraID(r.Context(), rep.CameraID); err == nil {
                targetCompanyID = cid
            }
        }
        // Ambil tokens untuk info
        tokens := []string{}
        if userRepo != nil {
            if list, err := userRepo.GetFCMTokensByCompanyAllRoles(r.Context(), targetCompanyID); err == nil {
                tokens = list
            }
        }
        ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
        defer cancel()
        if err := n.NotifyAnomaly(ctx, rep); err != nil {
            http.Error(w, "Gagal mengirim notifikasi", http.StatusBadGateway)
            return
        }
        w.Header().Set("Content-Type", "application/json")
        _ = json.NewEncoder(w).Encode(map[string]any{
            "ok": true,
            "anomaly_id": rep.ID,
            "camera_id": rep.CameraID,
            "company_id": targetCompanyID,
            "tokens_count": len(tokens),
        })
    }))

	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	// Aggregated health report for dashboard
	mux.HandleFunc("/api/health/report", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()

		resp := map[string]any{}

		// DB ping
		dbOK := db.PingContext(ctx) == nil
		resp["database"] = map[string]any{"ok": dbOK}

		// S3 buckets
		s3 := map[string]any{}
		archiveOK := false
		clipsOK := false
		if s3u != nil {
			if err := s3u.HeadBucketOnly(ctx, bucketArchive); err == nil {
				archiveOK = true
			}
			if err := s3u.HeadBucketOnly(ctx, clipsBucket); err == nil {
				clipsOK = true
			}
		}
		s3["archive_bucket"] = archiveOK
		s3["clips_bucket"] = clipsOK
		s3["ok"] = archiveOK && clipsOK
		resp["s3"] = s3

		// External services
		type extRes struct {
			Ok     bool `json:"ok"`
			Status int  `json:"status"`
		}
		probe := func(url string, method string) extRes {
			if url == "" {
				return extRes{Ok: false, Status: 0}
			}
			req, _ := http.NewRequestWithContext(ctx, method, url, nil)
			res, err := http.DefaultClient.Do(req)
			if err != nil {
				return extRes{Ok: false, Status: 0}
			}
			defer res.Body.Close()
			return extRes{Ok: res.StatusCode > 0 && res.StatusCode < 600, Status: res.StatusCode}
		}
		ingestBase := getEnv("UPLOAD_BASE_URL", "")
		pushBase := getEnv("PUSH_SERVICE_URL", "")
		mediaBase := getEnv("MEDIAMTX_URL", "")
		aiBase := getEnv("AI_WORKER_URL", "")

		ing := extRes{Ok: false, Status: 0}
		if ingestBase != "" {
			ing = probe(ingestBase+"/healthz", http.MethodGet)
		}
		resp["ingestion"] = ing

		aw := extRes{Ok: false, Status: 0}
		if aiBase != "" {
			aw = probe(aiBase+"/healthz", http.MethodGet)
		}
		resp["ai_worker"] = aw

		ps := extRes{Ok: false, Status: 0}
		if pushBase != "" {
			ps = probe(pushBase+"/send", http.MethodOptions)
		}
		resp["push_service"] = ps

		ms := extRes{Ok: false, Status: 0}
		if mediaBase != "" {
			ms = probe(mediaBase, http.MethodGet)
		}
		resp["media_server"] = ms

		// Backend self status (this handler is served by backend)
		resp["backend"] = extRes{Ok: true, Status: http.StatusOK}

		// RabbitMQ (optional): try TCP dial to host:port of RABBITMQ_URL
		rmq := map[string]any{"ok": false}
		if amqp := getEnv("RABBITMQ_URL", ""); amqp != "" {
			// crude parse: amqp://user:pass@host:port/vhost
			hostport := ""
			if strings.Contains(amqp, "@") {
				parts := strings.SplitN(amqp, "@", 2)
				hostPart := parts[1]
				// strip scheme leftovers
				if idx := strings.Index(hostPart, "/"); idx >= 0 {
					hostPart = hostPart[:idx]
				}
				hostport = hostPart
			}
			if hostport == "" {
				// fallback: remove scheme
				x := strings.TrimPrefix(amqp, "amqp://")
				if i := strings.Index(x, "/"); i >= 0 {
					x = x[:i]
				}
				hostport = x
			}
			conn, err := net.DialTimeout("tcp", hostport, 1500*time.Millisecond)
			if err == nil {
				_ = conn.Close()
				rmq["ok"] = true
			}
		}
		resp["rabbitmq"] = rmq

		// System snapshot: memory and disk
		var msnap runtime.MemStats
		runtime.ReadMemStats(&msnap)
		resp["system"] = map[string]any{
			"goroutines": runtime.NumGoroutine(),
			"mem_alloc":  msnap.Alloc,
			"mem_sys":    msnap.Sys,
		}
        if d, ok := getDiskStats(); ok {
            resp["disk"] = d
        }

		// Build info from env
		resp["build"] = map[string]string{
			"version": getEnv("BUILD_VERSION", ""),
			"commit":  getEnv("GIT_SHA", ""),
			"service": "cctv-main-backend",
		}

		// Optional S3 write test (safe small object)
		writeOK := false
		if s3u != nil {
			key := fmt.Sprintf(".health/%d.txt", time.Now().UnixNano())
			if err := s3u.PutObject(ctx, bucketArchive, key, []byte("ok")); err == nil {
				_ = s3u.DeleteObject(ctx, bucketArchive, key)
				writeOK = true
			}
		}
		if s3m, ok := resp["s3"].(map[string]any); ok {
			s3m["write_ok"] = writeOK
			s3m["ok"] = (s3m["ok"] == true) && writeOK
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	})

	port := "8080"
	fmt.Printf("Server berjalan di http://localhost:%s\n", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatal("Gagal memulai server:", err)
	}
}

func getEnv(key, def string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return def
}

// ensureSuperadmin creates or elevates a superadmin account if env vars are set
func ensureSuperadmin(db *sql.DB) {
    email := os.Getenv("SUPERADMIN_EMAIL")
    password := os.Getenv("SUPERADMIN_PASSWORD")
    if email == "" || password == "" {
        return
    }

	// Check if user exists
	var exists bool
	err := db.QueryRow("SELECT EXISTS(SELECT 1 FROM users WHERE email=$1)", email).Scan(&exists)
	if err != nil {
		log.Println("seed superadmin check error:", err)
		return
	}
    if exists {
        // Elevate role to superadmin and optionally reset password if env provided
        hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
        if err != nil {
            log.Println("bcrypt error:", err)
            return
        }
        if _, err := db.Exec("UPDATE users SET role='superadmin', password_hash=$2 WHERE email=$1", email, string(hash)); err != nil {
            log.Println("seed superadmin elevate/update error:", err)
        } else {
            log.Println("Superadmin elevated & password updated:", email)
        }
        return
    }

	// Create a system company if not exists
	var companyID int64
	if err := db.QueryRow("SELECT id FROM companies WHERE name=$1", "System").Scan(&companyID); err != nil {
		// create
		if err := db.QueryRow("INSERT INTO companies(name) VALUES($1) RETURNING id", "System").Scan(&companyID); err != nil {
			log.Println("create System company error:", err)
			return
		}
	}

	// Hash password and insert user
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		log.Println("bcrypt error:", err)
		return
	}
	if _, err := db.Exec("INSERT INTO users(email, password_hash, company_id, role) VALUES($1,$2,$3,$4)", email, string(hash), companyID, "superadmin"); err != nil {
		log.Println("insert superadmin error:", err)
		return
	}
	log.Println("Superadmin created:", email)
}
