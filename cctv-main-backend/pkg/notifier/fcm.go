package notifier

import (
	"cctv-main-backend/internal/domain"
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"time"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

type FCM struct {
	client *messaging.Client
	// cara kirim: byUserTokens (semua admin) atau byTopic (per kamera)
	UseTopic    bool
	TopicPrefix string // ex: "alerts"

	// Callback yang harus kamu inject dari repo:
	// - ambil semua token admin berdasarkan company
	GetAdminTokens func(ctx context.Context, companyID int64) ([]string, error)
	// - cari company_id berdasarkan camera_id
	GetCompanyIDByCameraID func(ctx context.Context, cameraID int64) (int64, error)
}

func NewFCM(ctx context.Context, credPath string) (*FCM, error) {
	if credPath == "" {
		credPath = os.Getenv("FIREBASE_CREDENTIALS")
	}
	if credPath == "" {
		return nil, errors.New("FIREBASE_CREDENTIALS tidak diset")
	}
	app, err := firebase.NewApp(ctx, nil, option.WithCredentialsFile(credPath))
	if err != nil {
		return nil, err
	}
	mc, err := app.Messaging(ctx)
	if err != nil {
		return nil, err
	}
	return &FCM{client: mc, TopicPrefix: "alerts"}, nil
}

// Send: wrapper agar memenuhi interface Notifier.
func (f *FCM) Send(report *domain.AnomalyReport) error {
	return f.NotifyAnomaly(context.Background(), report)
}

func (f *FCM) NotifyAnomaly(ctx context.Context, r *domain.AnomalyReport) error {
	title := "Anomali Terdeteksi"
	body := fmt.Sprintf("Kamera %d • %.0f%%", r.CameraID, r.Confidence*100)
	data := map[string]string{
		"camera_id":    fmt.Sprintf("%d", r.CameraID),
		"confidence":   fmt.Sprintf("%.3f", r.Confidence),
		"video_url":    r.VideoClipURL,
		"anomaly_type": r.AnomalyType,
	}

	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	// 1) Kirim via TOPIC kalau diminta
	if f.UseTopic {
		topic := fmt.Sprintf("%s-camera-%d", f.TopicPrefix, r.CameraID)
		_, err := f.client.Send(ctx, &messaging.Message{
			Topic:        topic,
			Notification: &messaging.Notification{Title: title, Body: body},
			Data:         data,
		})
		return err
	}

	// 2) Kalau tidak pakai topic, ambil company_id dari camera_id via callback
	var companyID int64
	if f.GetCompanyIDByCameraID != nil {
		id, err := f.GetCompanyIDByCameraID(ctx, r.CameraID)
		if err == nil {
			companyID = id
		}
	}

	// 3) Jika gagal mendapatkan company_id, fallback: kirim ke topic kamera
	if companyID == 0 {
		topic := fmt.Sprintf("%s-camera-%d", f.TopicPrefix, r.CameraID)
		_, err := f.client.Send(ctx, &messaging.Message{
			Topic:        topic,
			Notification: &messaging.Notification{Title: title, Body: body},
			Data:         data,
		})
		return err
	}

	// 4) Ambil token admin per company dan kirim multicast
	if f.GetAdminTokens == nil {
		return errors.New("GetAdminTokens nil")
	}
	tokens, err := f.GetAdminTokens(ctx, companyID)
	if err != nil {
		return err
	}
	if len(tokens) == 0 {
		return nil
	}

	success := 0
	failure := 0
	for i, t := range tokens {
		_, err := f.client.Send(ctx, &messaging.Message{
			Token:        t,
			Notification: &messaging.Notification{Title: title, Body: body},
			Data:         data,
		})
		if err != nil {
			failure++
			log.Printf("FCM: token[%d] failed: %v", i, err)
		} else {
			success++
		}
	}
	log.Printf("FCM: sent to %d tokens → success=%d failure=%d", len(tokens), success, failure)
	return nil

}
