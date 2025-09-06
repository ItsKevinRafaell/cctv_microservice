package notifier

import (
	"cctv-main-backend/internal/domain"
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

type FCM struct {
	client      *messaging.Client
	UseTopic    bool
	TopicPrefix string // ex: "alerts"

	GetAdminTokens         func(ctx context.Context, companyID int64) ([]string, error)
	GetCompanyIDByCameraID func(ctx context.Context, cameraID int64) (int64, error)
	DeleteToken            func(ctx context.Context, token string) error
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

func (f *FCM) Send(report *domain.AnomalyReport) error {
	return f.NotifyAnomaly(context.Background(), report)
}

func (f *FCM) NotifyAnomaly(ctx context.Context, r *domain.AnomalyReport) error {
	title := "Anomali Terdeteksi"
	body := fmt.Sprintf("Kamera %d • %.0f%%", r.CameraID, r.Confidence*100)
    data := map[string]string{
        "type":        "anomaly",
        "anomaly_id":  fmt.Sprintf("%d", r.ID),
        "camera_id":    fmt.Sprintf("%d", r.CameraID),
        "confidence":   fmt.Sprintf("%.3f", r.Confidence),
        "video_url":    r.VideoClipURL,
        "anomaly_type": r.AnomalyType,
        "deeplink":     fmt.Sprintf("app://camera/%d/anomaly", r.CameraID),
    }

	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	// Topic mode (opsional)
	if f.UseTopic {
		topic := fmt.Sprintf("%s-camera-%d", f.TopicPrefix, r.CameraID)
		_, err := f.client.Send(ctx, &messaging.Message{
			Topic:        topic,
			Notification: &messaging.Notification{Title: title, Body: body},
			Data:         data,
		})
		return err
	}

	// Map camera -> company
	var companyID int64
	if f.GetCompanyIDByCameraID != nil {
		if id, err := f.GetCompanyIDByCameraID(ctx, r.CameraID); err == nil {
			companyID = id
		}
	}
	// Fallback topic kalau companyID gagal
	if companyID == 0 && f.UseTopic {
		topic := fmt.Sprintf("%s-camera-%d", f.TopicPrefix, r.CameraID)
		_, err := f.client.Send(ctx, &messaging.Message{
			Topic:        topic,
			Notification: &messaging.Notification{Title: title, Body: body},
			Data:         data,
		})
		return err
	}

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

	// Kirim per token + auto-clean invalid
	success, failure := 0, 0
	for i, t := range tokens {
		_, err := f.client.Send(ctx, &messaging.Message{
			Token:        t,
			Notification: &messaging.Notification{Title: title, Body: body},
			Data:         data,
		})
		if err != nil {
			failure++
			log.Printf("FCM: token[%d] failed: %v", i, err)
			// Clean invalid/unregistered tokens
			if f.DeleteToken != nil && isInvalidTokenError(err) {
				if delErr := f.DeleteToken(ctx, t); delErr != nil {
					log.Printf("FCM: failed to clean token: %v", delErr)
				} else {
					log.Printf("FCM: token cleaned")
				}
			}
			continue
		}
		success++
	}
	log.Printf("FCM: sent to %d tokens → success=%d failure=%d", len(tokens), success, failure)
	return nil
}

// Heuristik sederhana untuk deteksi error token invalid/unregistered
func isInvalidTokenError(err error) bool {
	s := strings.ToLower(err.Error())
	return strings.Contains(s, "not a valid fcm registration token") ||
		strings.Contains(s, "requested entity was not found") || // unregistered
		strings.Contains(s, "unregistered") ||
		strings.Contains(s, "mismatch sender id")
}
