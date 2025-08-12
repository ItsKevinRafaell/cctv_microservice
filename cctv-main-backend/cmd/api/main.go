package main

import (
	"cctv-main-backend/internal/anomaly"
	"cctv-main-backend/internal/camera"
	"cctv-main-backend/internal/company"
	"cctv-main-backend/internal/user"
	"cctv-main-backend/pkg/database"
	"cctv-main-backend/pkg/notifier"
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	db := database.NewConnection()
	database.Migrate(db)
	defer db.Close()

	mux := http.NewServeMux()

	// repos
	anomalyRepo := anomaly.NewRepository(db)
	userRepo := user.NewRepository(db)
	companyRepo := company.NewRepository(db)
	cameraRepo := camera.NewRepository(db)

	// notifier: FCM jika kredensial ada, else log
	var n notifier.Notifier
	if cred := os.Getenv("FIREBASE_CREDENTIALS"); cred != "" {
		fcm, err := notifier.NewFCM(context.Background(), cred)
		if err != nil {
			log.Println("FCM init error, fallback ke log:", err)
			n = notifier.NewLogNotifier()
		} else {
			fcm.GetAdminTokens = userRepo.GetAdminFCMTokensByCompany
			fcm.GetCompanyIDByCameraID = cameraRepo.GetCompanyIDByCameraID
			fcm.DeleteToken = userRepo.DeleteFCMTokenByValue
			fcm.UseTopic = false // kirim langsung ke semua admin company
			fcm.TopicPrefix = "alerts"
			n = fcm // <-- penting!
		}
	} else {
		n = notifier.NewLogNotifier()
	}

	if _, ok := n.(*notifier.FCM); ok {
		log.Println("Notifier: FCM (direct-to-token)")
	} else {
		log.Println("Notifier: LOG (fallback)")
	}

	// services + handlers
	anomalyService := anomaly.NewService(anomalyRepo, n) // <<< gunakan n di sini
	anomalyHandler := anomaly.NewHandler(anomalyService)

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
	mux.HandleFunc("/api/anomalies/recent", authMiddleware(anomalyHandler.GetRecent))

	mux.HandleFunc("/api/companies", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodPost:
			companyHandler.CreateCompany(w, r)
		case http.MethodGet:
			companyHandler.GetAllCompanies(w, r)
		default:
			http.Error(w, "Metode tidak diizinkan", http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/api/companies/", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodPut:
			companyHandler.UpdateCompany(w, r)
		case http.MethodDelete:
			companyHandler.DeleteCompany(w, r)
		default:
			http.Error(w, "Metode tidak diizinkan", http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/api/cameras/", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
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
