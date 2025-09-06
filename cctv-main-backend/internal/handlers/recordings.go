// internal/handlers/recordings.go
package handlers

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

	"cctv-main-backend/internal/storage" // s3util kamu
)

type RecordingItem struct {
	Key  string `json:"key"`
	Size int64  `json:"size"`
	URL  string `json:"url,omitempty"`
}

type RecordingResponse struct {
	CameraID string          `json:"camera_id"`
	From     time.Time       `json:"from"`
	To       time.Time       `json:"to"`
	Count    int             `json:"count"`
	Items    []RecordingItem `json:"items"`
}

type RecordingHandler struct {
	DB     *sql.DB
	S3     *storage.S3Util // punya method Presign(bucket, key, ttl)
	Bucket string
}

func NewRecordingHandler(db *sql.DB, s3 *storage.S3Util, bucket string) *RecordingHandler {
	return &RecordingHandler{DB: db, S3: s3, Bucket: bucket}
}

func (h *RecordingHandler) ListRecordings(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")

	// path: /api/cameras/{id}/recordings
	parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	if len(parts) < 4 {
		http.Error(w, `{"error":"bad path"}`, http.StatusBadRequest)
		return
	}
	cameraID := parts[2]
	// Jika path berupa angka (id kamera), konversi ke stream_key terlebih dahulu
	if isDigits(cameraID) {
		var sk sql.NullString
		if err := h.DB.QueryRow(`SELECT stream_key FROM cameras WHERE id=$1`, cameraID).Scan(&sk); err == nil && sk.Valid && sk.String != "" {
			cameraID = sk.String
		}
	}

	// window waktu: default 24 jam terakhir
	now := time.Now().UTC()
	from := now.Add(-24 * time.Hour)
	to := now

	if vf := r.URL.Query().Get("from"); vf != "" {
		if t, err := time.Parse(time.RFC3339, vf); err == nil {
			from = t
		}
	}
	if vt := r.URL.Query().Get("to"); vt != "" {
		if t, err := time.Parse(time.RFC3339, vt); err == nil {
			to = t
		}
	}
	if !from.Before(to) {
		http.Error(w, `{"error":"from must be < to"}`, http.StatusBadRequest)
		return
	}

	rows, err := h.DB.Query(`
		SELECT s3_key, size_bytes
		FROM recordings
		WHERE camera_id = $1 AND started_at >= $2 AND started_at < $3
		ORDER BY started_at ASC
	`, cameraID, from, to)
	if err != nil {
		log.Printf("query recordings err: %v", err)
		http.Error(w, `{"error":"db error"}`, http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	presign := r.URL.Query().Get("presign") == "1"
	var items []RecordingItem
	for rows.Next() {
		var key string
		var size int64
		if err := rows.Scan(&key, &size); err != nil {
			log.Printf("scan err: %v", err)
			continue
		}
		it := RecordingItem{Key: key, Size: size}
		if presign && h.S3 != nil {
			if url, err := h.S3.Presign(h.Bucket, key, 24*time.Hour); err == nil {
				it.URL = url
			} else {
				log.Printf("presign %s err: %v", key, err)
			}
		}
		items = append(items, it)
	}

	resp := RecordingResponse{
		CameraID: cameraID,
		From:     from,
		To:       to,
		Count:    len(items),
		Items:    items,
	}
	_ = json.NewEncoder(w).Encode(resp)
}

func isDigits(s string) bool {
	if s == "" {
		return false
	}
	for _, c := range s {
		if c < '0' || c > '9' {
			return false
		}
	}
	return true
}
