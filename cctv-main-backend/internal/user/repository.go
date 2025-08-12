package user

import (
	"cctv-main-backend/internal/domain"
	"database/sql"
)

type Repository interface {
	CreateUser(user *domain.User) error
	GetUserByEmail(email string) (*domain.User, error)
	GetUsersByCompanyID(companyID int64) ([]domain.User, error)
	UpdateUserRole(userID, companyID int64, role string) error
	DeleteUser(userID, companyID int64) error
}

type repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) Repository {
	return &repository{db: db}
}

func (r *repository) GetUserByEmail(email string) (*domain.User, error) {
	var user domain.User
	query := `SELECT id, email, password_hash, company_id, role FROM users WHERE email=$1`

	err := r.db.QueryRow(query, email).Scan(&user.ID, &user.Email, &user.PasswordHash, &user.CompanyID, &user.Role)
	if err != nil {
		return nil, err
	}

	return &user, nil
}

func (r *repository) CreateUser(user *domain.User) error {
	query := `INSERT INTO users (email, password_hash, company_id, role) VALUES ($1, $2, $3, $4)`
	_, err := r.db.Exec(query, user.Email, user.PasswordHash, user.CompanyID, user.Role)
	return err
}

func (r *repository) GetUsersByCompanyID(companyID int64) ([]domain.User, error) {
	query := `SELECT id, email, role, company_id FROM users WHERE company_id = $1 ORDER BY id ASC`
	rows, err := r.db.Query(query, companyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []domain.User
	for rows.Next() {
		var u domain.User
		if err := rows.Scan(&u.ID, &u.Email, &u.Role, &u.CompanyID); err != nil {
			return nil, err
		}
		users = append(users, u)
	}
	return users, nil
}

func (r *repository) UpdateUserRole(userID, companyID int64, role string) error {
	query := `UPDATE users SET role = $1 WHERE id = $2 AND company_id = $3`
	result, err := r.db.Exec(query, role, userID, companyID)
	if err != nil {
		return err
	}
	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *repository) DeleteUser(userID, companyID int64) error {
	query := `DELETE FROM users WHERE id = $1 AND company_id = $2`
	result, err := r.db.Exec(query, userID, companyID)
	if err != nil {
		return err
	}
	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return sql.ErrNoRows
	}
	return nil
}
