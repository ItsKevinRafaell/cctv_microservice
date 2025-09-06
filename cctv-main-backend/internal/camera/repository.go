package camera

import (
	"cctv-main-backend/internal/domain"
	"context"
	"database/sql"
	"errors"
	"fmt"

	pqx "github.com/lib/pq"
)

type Repository interface {
	CreateCamera(camera *domain.Camera) (int64, error)
	GetCamerasByCompanyID(companyID int64) ([]domain.Camera, error)
	UpdateCamera(camera *domain.Camera) error
	DeleteCamera(cameraID int64, companyID int64) error
	// NEW: ambil company_id berdasarkan camera_id (untuk FCM)
	GetCompanyIDByCameraID(ctx context.Context, cameraID int64) (int64, error)
}

type repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) Repository {
	return &repository{db: db}
}

func (r *repository) CreateCamera(camera *domain.Camera) (int64, error) {
	var cameraID int64
	// Insert dulu; stream_key bisa dikosongkan, nanti diisi 'cam<id>' bila tidak diberikan
	query := `INSERT INTO cameras (name, location, company_id, stream_key, rtsp_source)
              VALUES ($1, $2, $3, $4, $5) RETURNING id`
	err := r.db.QueryRow(query, camera.Name, camera.Location, camera.CompanyID, camera.StreamKey, camera.RTSPSource).Scan(&cameraID)
	if err != nil {
		if pe, ok := err.(*pqx.Error); ok && string(pe.Code) == "23505" {
			return 0, ErrStreamKeyConflict
		}
		return 0, err
	}
	// jika stream_key kosong, set default 'cam<id>'
	if camera.StreamKey == "" {
		_, _ = r.db.Exec(`UPDATE cameras SET stream_key = $1 WHERE id = $2 AND (stream_key IS NULL OR stream_key = '')`,
			"cam"+fmt.Sprint(cameraID), cameraID)
	}
	return cameraID, nil
}

func (r *repository) GetCamerasByCompanyID(companyID int64) ([]domain.Camera, error) {
	query := `SELECT id, name, location, stream_key, rtsp_source, company_id, created_at FROM cameras WHERE company_id = $1 ORDER BY created_at DESC`
	rows, err := r.db.Query(query, companyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var cameras []domain.Camera
	for rows.Next() {
		var cam domain.Camera
		if err := rows.Scan(&cam.ID, &cam.Name, &cam.Location, &cam.StreamKey, &cam.RTSPSource, &cam.CompanyID, &cam.CreatedAt); err != nil {
			return nil, err
		}
		cameras = append(cameras, cam)
	}
	return cameras, nil
}

func (r *repository) UpdateCamera(camera *domain.Camera) error {
	query := `UPDATE cameras SET name = $1, location = $2, stream_key = COALESCE(NULLIF($3,''), stream_key), rtsp_source = $4 WHERE id = $5 AND company_id = $6`

	result, err := r.db.Exec(query, camera.Name, camera.Location, camera.StreamKey, camera.RTSPSource, camera.ID, camera.CompanyID)
	if err != nil {
		if pe, ok := err.(*pqx.Error); ok && string(pe.Code) == "23505" {
			return ErrStreamKeyConflict
		}
		return err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}

	if rowsAffected == 0 {
		return errors.New("kamera tidak ditemukan atau bukan milik perusahaan anda")
	}

	return nil
}

var ErrStreamKeyConflict = errors.New("stream_key already exists")

func (r *repository) DeleteCamera(cameraID int64, companyID int64) error {
	query := `DELETE FROM cameras WHERE id = $1 AND company_id = $2`

	result, err := r.db.Exec(query, cameraID, companyID)
	if err != nil {
		return err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}

	if rowsAffected == 0 {
		return errors.New("kamera tidak ditemukan atau bukan milik perusahaan anda")
	}

	return nil
}

// NEW: lookup company_id dari camera_id (dipakai FCM untuk ambil token admin per company)
func (r *repository) GetCompanyIDByCameraID(ctx context.Context, cameraID int64) (int64, error) {
	var companyID int64
	err := r.db.QueryRowContext(ctx, `SELECT company_id FROM cameras WHERE id = $1`, cameraID).Scan(&companyID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			// kamera tidak ditemukan → kembalikan 0 (biar FCM fallback ke topic)
			return 0, nil
		}
		return 0, err
	}
	return companyID, nil
}
