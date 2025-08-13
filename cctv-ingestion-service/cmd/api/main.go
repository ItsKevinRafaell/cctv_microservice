package main

import (
	"cctv-ingestion-service/internal/ingest"
	"cctv-ingestion-service/pkg/mq"
	"cctv-ingestion-service/pkg/uploader"
	"fmt"
	"log"
	"net/http"
	"time"
)

func main() {
	// MinIO (intra-docker)
	s3Uploader, err := uploader.NewS3Uploader(
		"http://minio:9000",
		"minioadmin",
		"minio-secret-key",
		"video-clips",
	)
	if err != nil {
		log.Fatalf("Gagal init S3 Uploader: %v", err)
	}

	// RabbitMQ (intra-docker)
	rabbitPublisher, err := mq.NewRabbitMQPublisher("amqp://guest:guest@rabbitmq:5672/")
	if err != nil {
		log.Fatalf("Gagal terhubung ke RabbitMQ: %v", err)
	}
	defer rabbitPublisher.Close()
	log.Println("✅ Berhasil terhubung ke RabbitMQ!")

	ingestService := ingest.NewService(s3Uploader, rabbitPublisher)
	ingestHandler := ingest.NewHandler(ingestService)

	// Router explicit + healthz
	mux := http.NewServeMux()
	mux.HandleFunc("/ingest/video", ingestHandler.VideoIngestHandler) // endpoint kamu
	mux.HandleFunc("/upload", ingestHandler.VideoIngestHandler)       // alias (opsional)
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("ok"))
	})

	// Server dengan timeouts (hindari “loading terus”)
	srv := &http.Server{
		Addr:              ":8081",
		Handler:           logMiddleware(mux),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       60 * time.Second,
		WriteTimeout:      60 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	fmt.Println("Server penerima video (Ingestion Service) berjalan di http://localhost:8081")
	if err := srv.ListenAndServe(); err != nil {
		log.Fatal("Gagal memulai server:", err)
	}
}

func logMiddleware(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s", r.Method, r.URL.Path)
		h.ServeHTTP(w, r)
	})
}
