package camera

import (
	"cctv-main-backend/internal/domain"
	"database/sql"
	"errors"
)

type Repository interface {
	CreateCamera(camera *domain.Camera) (int64, error)
	GetCamerasByCompanyID(companyID int64) ([]domain.Camera, error)
	UpdateCamera(camera *domain.Camera) error
	DeleteCamera(cameraID int64, companyID int64) error
}

type repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) Repository {
	return &repository{db: db}
}

func (r *repository) CreateCamera(camera *domain.Camera) (int64, error) {
	var cameraID int64
	query := `INSERT INTO cameras (name, location, company_id) VALUES ($1, $2, $3) RETURNING id`
	err := r.db.QueryRow(query, camera.Name, camera.Location, camera.CompanyID).Scan(&cameraID)
	if err != nil {
		return 0, err
	}
	return cameraID, nil
}

func (r *repository) GetCamerasByCompanyID(companyID int64) ([]domain.Camera, error) {
	query := `SELECT id, name, location, company_id, created_at FROM cameras WHERE company_id = $1 ORDER BY created_at DESC`
	rows, err := r.db.Query(query, companyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var cameras []domain.Camera
	for rows.Next() {
		var cam domain.Camera
		if err := rows.Scan(&cam.ID, &cam.Name, &cam.Location, &cam.CompanyID, &cam.CreatedAt); err != nil {
			return nil, err
		}
		cameras = append(cameras, cam)
	}
	return cameras, nil
}

func (r *repository) UpdateCamera(camera *domain.Camera) error {
	query := `UPDATE cameras SET name = $1, location = $2 WHERE id = $3 AND company_id = $4`

	result, err := r.db.Exec(query, camera.Name, camera.Location, camera.ID, camera.CompanyID)
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
