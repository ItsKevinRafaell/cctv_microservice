package main

import (
	"cctv-main-backend/internal/anomaly"
	"cctv-main-backend/internal/camera"
	"cctv-main-backend/internal/company"
	"cctv-main-backend/internal/user"
	"cctv-main-backend/pkg/database"
	"cctv-main-backend/pkg/notifier"
	"fmt"
	"log"
	"net/http"
)

func main() {
	db := database.NewConnection()
	database.Migrate(db)
	defer db.Close()

	logNotifier := notifier.NewLogNotifier()
	mux := http.NewServeMux()

	anomalyRepo := anomaly.NewRepository(db)
	anomalyService := anomaly.NewService(anomalyRepo, logNotifier)
	anomalyHandler := anomaly.NewHandler(anomalyService)

	userRepo := user.NewRepository(db)
	userService := user.NewService(userRepo)
	userHandler := user.NewHandler(userService)

	companyRepo := company.NewRepository(db)
	companyService := company.NewService(companyRepo)
	companyHandler := company.NewHandler(companyService)

	cameraRepo := camera.NewRepository(db)
	cameraService := camera.NewService(cameraRepo)
	cameraHandler := camera.NewHandler(cameraService)

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

	port := "8080"
	fmt.Printf("Server berjalan di http://localhost:%s\n", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatal("Gagal memulai server:", err)
	}
}
