package user

import (
	"cctv-main-backend/internal/domain"
	"context"
	"database/sql"
)

type Repository interface {
    CreateUser(user *domain.User) error
    GetUserByEmail(email string) (*domain.User, error)
    GetUsersByCompanyID(companyID int64) ([]domain.User, error)
    GetUserRoleByCompany(userID, companyID int64) (string, error)
    UpdateUserRole(userID, companyID int64, role string) error
    UpdateUserEmail(userID, companyID int64, email string) error
    UpdateUserPassword(userID, companyID int64, passwordHash string) error
    UpdateUserName(userID, companyID int64, name string) error
    DeleteUser(userID, companyID int64) error
    UpdateFCMToken(userID int64, fcmToken string) error
    GetAdminFCMTokensByCompany(ctx context.Context, companyID int64) ([]string, error)
    GetFCMTokensByCompanyAllRoles(ctx context.Context, companyID int64) ([]string, error)
    DeleteFCMTokenByValue(ctx context.Context, token string) error
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
    // company_id can be NULL when creating global superadmin
    if user.CompanyID == 0 {
        _, err := r.db.Exec(`INSERT INTO users (email, password_hash, company_id, role, display_name) VALUES ($1, $2, NULL, $3, $4)`,
            user.Email, user.PasswordHash, user.Role, user.Name,
        )
        return err
    }
    _, err := r.db.Exec(`INSERT INTO users (email, password_hash, company_id, role, display_name) VALUES ($1, $2, $3, $4, $5)`,
        user.Email, user.PasswordHash, user.CompanyID, user.Role, user.Name,
    )
    return err
}

func (r *repository) GetUsersByCompanyID(companyID int64) ([]domain.User, error) {
    query := `SELECT id, email, role, company_id, COALESCE(display_name,'') as name FROM users WHERE company_id = $1 ORDER BY id ASC`
    rows, err := r.db.Query(query, companyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

    users := make([]domain.User, 0)
	for rows.Next() {
		var u domain.User
        if err := rows.Scan(&u.ID, &u.Email, &u.Role, &u.CompanyID, &u.Name); err != nil {
            return nil, err
        }
        users = append(users, u)
    }
    return users, nil
}

func (r *repository) GetUserRoleByCompany(userID, companyID int64) (string, error) {
    var role string
    err := r.db.QueryRow(`SELECT role FROM users WHERE id = $1 AND company_id = $2`, userID, companyID).Scan(&role)
    if err != nil {
        return "", err
    }
    return role, nil
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

func (r *repository) UpdateUserEmail(userID, companyID int64, email string) error {
    result, err := r.db.Exec(`UPDATE users SET email = $1 WHERE id = $2 AND (company_id = $3 OR (company_id IS NULL AND $3 = 0))`, email, userID, companyID)
    if err != nil { return err }
    if ra, _ := result.RowsAffected(); ra == 0 { return sql.ErrNoRows }
    return nil
}

func (r *repository) UpdateUserPassword(userID, companyID int64, passwordHash string) error {
    result, err := r.db.Exec(`UPDATE users SET password_hash = $1 WHERE id = $2 AND (company_id = $3 OR (company_id IS NULL AND $3 = 0))`, passwordHash, userID, companyID)
    if err != nil { return err }
    if ra, _ := result.RowsAffected(); ra == 0 { return sql.ErrNoRows }
    return nil
}

func (r *repository) UpdateUserName(userID, companyID int64, name string) error {
    result, err := r.db.Exec(`UPDATE users SET display_name = $1 WHERE id = $2 AND (company_id = $3 OR (company_id IS NULL AND $3 = 0))`, name, userID, companyID)
    if err != nil { return err }
    if ra, _ := result.RowsAffected(); ra == 0 { return sql.ErrNoRows }
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

func (r *repository) UpdateFCMToken(userID int64, fcmToken string) error {
	query := `UPDATE users SET fcm_token = $1 WHERE id = $2`
	result, err := r.db.Exec(query, fcmToken, userID)
	if err != nil {
		return err
	}
	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *repository) GetAdminFCMTokensByCompany(ctx context.Context, companyID int64) ([]string, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT fcm_token
		FROM users
		WHERE company_id=$1 AND role='company_admin' AND fcm_token IS NOT NULL AND fcm_token <> ''`,
		companyID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var tokens []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, err
		}
		tokens = append(tokens, t)
	}
	return tokens, rows.Err()
}

// GetFCMTokensByCompanyAllRoles returns FCM tokens for both company_admin and user roles
func (r *repository) GetFCMTokensByCompanyAllRoles(ctx context.Context, companyID int64) ([]string, error) {
    rows, err := r.db.QueryContext(ctx, `
        SELECT fcm_token
        FROM users
        WHERE company_id=$1 AND role IN ('company_admin','user') AND fcm_token IS NOT NULL AND fcm_token <> ''`,
        companyID,
    )
    if err != nil {
        return nil, err
    }
    defer rows.Close()
    var tokens []string
    for rows.Next() {
        var t string
        if err := rows.Scan(&t); err != nil {
            return nil, err
        }
        tokens = append(tokens, t)
    }
    return tokens, rows.Err()
}

func (r *repository) DeleteFCMTokenByValue(ctx context.Context, token string) error {
	_, err := r.db.ExecContext(ctx, `UPDATE users SET fcm_token = NULL WHERE fcm_token = $1`, token)
	return err
}
