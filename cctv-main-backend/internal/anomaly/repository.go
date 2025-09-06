package anomaly

import (
	"cctv-main-backend/internal/domain"
	"database/sql"
	"time"
)

type Repository interface {
    CreateReport(report *domain.AnomalyReport) error
    GetAllReportsByCompany(companyID int64) ([]domain.AnomalyReport, error)
    GetRecentReportsByCompany(companyID int64, limit int) ([]domain.AnomalyReport, error)
    GetByIDForCompany(companyID int64, id int64) (*domain.AnomalyReport, error)
}

type repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) Repository {
	return &repository{db: db}
}

func (r *repository) CreateReport(report *domain.AnomalyReport) error {
	query := `INSERT INTO anomaly_reports (camera_id, anomaly_type, confidence, video_clip_url, reported_at) VALUES ($1, $2, $3, $4, $5)`
	_, err := r.db.Exec(query, report.CameraID, report.AnomalyType, report.Confidence, report.VideoClipURL, time.Now())
	return err
}

func (r *repository) GetAllReportsByCompany(companyID int64) ([]domain.AnomalyReport, error) {
    // If companyID <= 0, return all
    var rows *sql.Rows
    var err error
    if companyID <= 0 {
        rows, err = r.db.Query(`
            SELECT r.id, r.camera_id, r.anomaly_type, r.confidence, r.video_clip_url, r.reported_at
            FROM anomaly_reports r
            JOIN cameras c ON r.camera_id = c.id
            ORDER BY r.reported_at DESC`)
    } else {
        rows, err = r.db.Query(`
            SELECT r.id, r.camera_id, r.anomaly_type, r.confidence, r.video_clip_url, r.reported_at
            FROM anomaly_reports r
            JOIN cameras c ON r.camera_id = c.id
            WHERE c.company_id = $1
            ORDER BY r.reported_at DESC`, companyID)
    }
    if err != nil {
        return nil, err
    }
    defer rows.Close()

    reports := make([]domain.AnomalyReport, 0)
	for rows.Next() {
		var report domain.AnomalyReport
		// Sesuaikan Scan untuk membaca kolom baru
		if err := rows.Scan(&report.ID, &report.CameraID, &report.AnomalyType, &report.Confidence, &report.VideoClipURL, &report.ReportedAt); err != nil {
			return nil, err
		}
		reports = append(reports, report)
	}
	return reports, nil
}

func (r *repository) GetRecentReportsByCompany(companyID int64, limit int) ([]domain.AnomalyReport, error) {
    if limit <= 0 {
        limit = 20
    }
    var rows *sql.Rows
    var err error
    if companyID <= 0 {
        rows, err = r.db.Query(`
            SELECT r.id, r.camera_id, r.anomaly_type, r.confidence, r.video_clip_url, r.reported_at
            FROM anomaly_reports r
            JOIN cameras c ON r.camera_id = c.id
            ORDER BY r.reported_at DESC
            LIMIT $1`, limit)
    } else {
        rows, err = r.db.Query(`
            SELECT r.id, r.camera_id, r.anomaly_type, r.confidence, r.video_clip_url, r.reported_at
            FROM anomaly_reports r
            JOIN cameras c ON r.camera_id = c.id
            WHERE c.company_id = $1
            ORDER BY r.reported_at DESC
            LIMIT $2`, companyID, limit)
    }
    if err != nil {
        return nil, err
    }
    defer rows.Close()

    reports := make([]domain.AnomalyReport, 0)
	for rows.Next() {
		var report domain.AnomalyReport
		if err := rows.Scan(&report.ID, &report.CameraID, &report.AnomalyType, &report.Confidence, &report.VideoClipURL, &report.ReportedAt); err != nil {
			return nil, err
		}
		reports = append(reports, report)
	}
	return reports, rows.Err()
}

func (r *repository) GetByIDForCompany(companyID int64, id int64) (*domain.AnomalyReport, error) {
    var row *sql.Row
    if companyID <= 0 {
        row = r.db.QueryRow(`
            SELECT r.id, r.camera_id, r.anomaly_type, r.confidence, r.video_clip_url, r.reported_at
            FROM anomaly_reports r
            JOIN cameras c ON r.camera_id = c.id
            WHERE r.id = $1`, id)
    } else {
        row = r.db.QueryRow(`
            SELECT r.id, r.camera_id, r.anomaly_type, r.confidence, r.video_clip_url, r.reported_at
            FROM anomaly_reports r
            JOIN cameras c ON r.camera_id = c.id
            WHERE c.company_id = $1 AND r.id = $2`, companyID, id)
    }
    var report domain.AnomalyReport
    err := row.Scan(&report.ID, &report.CameraID, &report.AnomalyType, &report.Confidence, &report.VideoClipURL, &report.ReportedAt)
    if err != nil {
        return nil, err
    }
    return &report, nil
}
