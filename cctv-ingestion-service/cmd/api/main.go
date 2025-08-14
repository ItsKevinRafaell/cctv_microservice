package main

import (
	"cctv-ingestion-service/internal/ingest"
	"cctv-ingestion-service/pkg/mq"
	"cctv-ingestion-service/pkg/uploader"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
)

func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func main() {
	internalEndpoint := getEnv("MINIO_INTERNAL_ENDPOINT", "http://minio:9000")
	publicEndpoint := getEnv("MINIO_PUBLIC_ENDPOINT", "http://127.0.0.1:9000")
	publicBaseURL := getEnv("MINIO_PUBLIC_BASE_URL", publicEndpoint)
	accessKey := getEnv("MINIO_ACCESS_KEY", "minioadmin")
	secretKey := getEnv("MINIO_SECRET_KEY", "minio-secret-key")
	bucket := getEnv("MINIO_BUCKET", "video-clips")
	usePresignStr := getEnv("MINIO_USE_PRESIGN", "true")
	presignTTLStr := getEnv("MINIO_PRESIGN_TTL", "86400")

	usePresign := usePresignStr == "true" || usePresignStr == "1"
	ttl, _ := strconv.Atoi(presignTTLStr)

	s3Uploader, err := uploader.NewS3Uploader(
		internalEndpoint, publicEndpoint, accessKey, secretKey, bucket,
		usePresign, ttl, publicBaseURL,
	)
	if err != nil {
		log.Fatalf("Init S3 Uploader error: %v", err)
	}

	rabbitPublisher, err := mq.NewRabbitMQPublisher("amqp://guest:guest@rabbitmq:5672/")
	if err != nil {
		log.Fatalf("Gagal terhubung ke RabbitMQ: %v", err)
	}
	defer rabbitPublisher.Close()
	log.Println("✅ Berhasil terhubung ke RabbitMQ!")

	ingestService := ingest.NewService(s3Uploader, rabbitPublisher)
	ingestHandler := ingest.NewHandler(ingestService)

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) { w.Write([]byte("ok")) })
	mux.HandleFunc("/ingest/video", ingestHandler.VideoIngestHandler)

	port := getEnv("PORT", "8081")
	fmt.Printf("Server penerima video (Ingestion Service) berjalan di http://localhost:%s\n", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatal("Gagal memulai server:", err)
	}
}
