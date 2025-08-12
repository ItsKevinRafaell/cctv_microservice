package domain

import "time"

type Camera struct {
	ID        int64     `json:"id"`
	Name      string    `json:"name"`
	Location  string    `json:"location,omitempty"`
	CompanyID int64     `json:"company_id"`
	CreatedAt time.Time `json:"created_at"`
}
