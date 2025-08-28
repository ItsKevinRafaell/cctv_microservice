package domain

import "time"

type Camera struct {
    ID        int64     `json:"id"`
    Name      string    `json:"name"`
    Location  string    `json:"location,omitempty"`
    StreamKey string    `json:"stream_key,omitempty"`
    RTSPSource string   `json:"rtsp_source,omitempty"`
    CompanyID int64     `json:"company_id"`
    CreatedAt time.Time `json:"created_at"`
}
