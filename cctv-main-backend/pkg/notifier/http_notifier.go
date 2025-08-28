package notifier

import (
    "bytes"
    "cctv-main-backend/internal/domain"
    "context"
    "encoding/json"
    "errors"
    "fmt"
    "net/http"
    "time"
)

// HTTPNotifier mengirim payload notifikasi ke layanan push-service via HTTP.
type HTTPNotifier struct {
    BaseURL string
    Secret  string

    // Hooks dari repo untuk ambil token dan company mapping
    GetAdminTokens         func(ctx context.Context, companyID int64) ([]string, error)
    GetCompanyIDByCameraID func(ctx context.Context, cameraID int64) (int64, error)
}

func NewHTTPNotifier(baseURL string) (*HTTPNotifier, error) { // kept for compatibility
    if baseURL == "" {
        return nil, errors.New("baseURL kosong untuk HTTPNotifier")
    }
    return &HTTPNotifier{BaseURL: baseURL}, nil
}

func NewHTTPNotifierWithSecret(baseURL, secret string) (*HTTPNotifier, error) {
    if baseURL == "" {
        return nil, errors.New("baseURL kosong untuk HTTPNotifier")
    }
    return &HTTPNotifier{BaseURL: baseURL, Secret: secret}, nil
}

func (n *HTTPNotifier) Send(report *domain.AnomalyReport) error {
    return n.NotifyAnomaly(context.Background(), report)
}

func (n *HTTPNotifier) NotifyAnomaly(ctx context.Context, r *domain.AnomalyReport) error {
    if n.GetCompanyIDByCameraID == nil || n.GetAdminTokens == nil {
        return errors.New("dependency GetCompanyIDByCameraID/GetAdminTokens nil")
    }
    companyID, err := n.GetCompanyIDByCameraID(ctx, r.CameraID)
    if err != nil {
        return fmt.Errorf("map camera->company: %w", err)
    }
    tokens, err := n.GetAdminTokens(ctx, companyID)
    if err != nil {
        return fmt.Errorf("get admin tokens: %w", err)
    }
    if len(tokens) == 0 {
        return nil
    }

    payload := map[string]any{
        "tokens": tokens,
        "title":  "Anomali Terdeteksi",
        "body":   fmt.Sprintf("Kamera %d • %.0f%%", r.CameraID, r.Confidence*100),
        "data": map[string]string{
            "camera_id":    fmt.Sprintf("%d", r.CameraID),
            "confidence":   fmt.Sprintf("%.3f", r.Confidence),
            "video_url":    r.VideoClipURL,
            "anomaly_type": r.AnomalyType,
            "deeplink":     fmt.Sprintf("app://camera/%d/anomaly", r.CameraID),
        },
    }
    b, _ := json.Marshal(payload)

    req, err := http.NewRequestWithContext(ctx, http.MethodPost, n.BaseURL+"/send", bytes.NewReader(b))
    if err != nil { return err }
    req.Header.Set("Content-Type", "application/json")
    if n.Secret != "" {
        req.Header.Set("X-Push-Secret", n.Secret)
    }

    httpClient := &http.Client{ Timeout: 5 * time.Second }
    resp, err := httpClient.Do(req)
    if err != nil {
        return err
    }
    defer resp.Body.Close()
    if resp.StatusCode < 200 || resp.StatusCode >= 300 {
        return fmt.Errorf("push-service non-2xx: %s", resp.Status)
    }
    return nil
}
