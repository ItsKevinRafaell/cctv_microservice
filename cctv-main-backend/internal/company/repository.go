package company

import (
	"cctv-main-backend/internal/domain"
	"database/sql"
)

type Repository interface {
	CreateCompany(company *domain.Company) (int64, error)
	GetAllCompanies() ([]domain.Company, error)
	UpdateCompany(company *domain.Company) error
	DeleteCompany(companyID int64) error
}

type repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) Repository {
	return &repository{db: db}
}

func (r *repository) CreateCompany(company *domain.Company) (int64, error) {
	var companyID int64
	query := `INSERT INTO companies (name) VALUES ($1) RETURNING id`
	err := r.db.QueryRow(query, company.Name).Scan(&companyID)
	if err != nil {
		return 0, err
	}
	return companyID, nil
}

func (r *repository) GetAllCompanies() ([]domain.Company, error) {
	query := `SELECT id, name, created_at FROM companies ORDER BY id ASC`
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

    companies := make([]domain.Company, 0)
	for rows.Next() {
		var c domain.Company
		if err := rows.Scan(&c.ID, &c.Name, &c.CreatedAt); err != nil {
			return nil, err
		}
		companies = append(companies, c)
	}
	return companies, nil
}

func (r *repository) UpdateCompany(company *domain.Company) error {
	query := `UPDATE companies SET name = $1 WHERE id = $2`
	result, err := r.db.Exec(query, company.Name, company.ID)
	if err != nil {
		return err
	}
	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *repository) DeleteCompany(companyID int64) error {
	query := `DELETE FROM companies WHERE id = $1`
	result, err := r.db.Exec(query, companyID)
	if err != nil {
		return err
	}
	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return sql.ErrNoRows
	}
	return nil
}
