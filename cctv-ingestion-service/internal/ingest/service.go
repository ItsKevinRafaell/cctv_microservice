package ingest

import (
	"cctv-ingestion-service/pkg/mq"
	"cctv-ingestion-service/pkg/uploader"
	"mime/multipart"
)

type Service interface {
	// NEW: terima cameraIDStr
	ProcessVideo(file multipart.File, handler *multipart.FileHeader, cameraIDStr string) error
}

type service struct {
	uploader  *uploader.S3Uploader
	publisher *mq.RabbitMQPublisher
}

func NewService(uploader *uploader.S3Uploader, publisher *mq.RabbitMQPublisher) Service {
	return &service{uploader: uploader, publisher: publisher}
}

func (s *service) ProcessVideo(file multipart.File, handler *multipart.FileHeader, cameraIDStr string) error {
	fileURL, filePath, err := s.uploader.Save(file, handler)
	if err != nil {
		return err
	}

	// NEW: sertakan camera_id dan original_filename
	taskMessage := map[string]string{
		"video_url":         fileURL,
		"video_path":        filePath,
		"original_filename": handler.Filename,
		"camera_id":         cameraIDStr,
	}

	return s.publisher.Publish("video_analysis_tasks", taskMessage)
}
