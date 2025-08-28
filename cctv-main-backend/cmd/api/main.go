package main

import (
	"cctv-main-backend/internal/anomaly"
	"cctv-main-backend/internal/camera"
	"cctv-main-backend/internal/company"
	"cctv-main-backend/internal/handlers"
	"cctv-main-backend/internal/storage"
	"cctv-main-backend/internal/user"
	"cctv-main-backend/pkg/database"
	"cctv-main-backend/pkg/notifier"
	"database/sql"
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
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
            httpN.GetAdminTokens = userRepo.GetAdminFCMTokensByCompany
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
                fcm.GetAdminTokens = userRepo.GetAdminFCMTokensByCompany
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
	mux.HandleFunc("/api/register", userHandler.Register)
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

	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
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
        // Elevate role to superadmin
        if _, err := db.Exec("UPDATE users SET role='superadmin' WHERE email=$1", email); err != nil {
            log.Println("seed superadmin elevate error:", err)
        } else {
            log.Println("Superadmin elevated:", email)
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
