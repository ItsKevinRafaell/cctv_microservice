package user

import (
    "cctv-main-backend/internal/domain"
    "context"
    "database/sql"
    "errors"

    pqx "github.com/lib/pq"
)

type Repository interface {
    CreateUser(user *domain.User) error
    GetUserByEmail(email string) (*domain.User, error)
    GetUsersByCompanyID(companyID int64) ([]domain.User, error)
    GetAllUsers() ([]domain.User, error)
    UpdateUserRole(userID, companyID int64, role string) error
    DeleteUser(userID, companyID int64) error
    UpdateFCMToken(userID int64, fcmToken string) error
    GetAdminFCMTokensByCompany(ctx context.Context, companyID int64) ([]string, error)
    DeleteFCMTokenByValue(ctx context.Context, token string) error
    // All roles tokens for a company (non-empty)
    GetFCMTokensByCompanyAllRoles(ctx context.Context, companyID int64) ([]string, error)
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
    // Allow NULL company_id when not provided (e.g., superadmin user without a specific company)
    var companyArg interface{}
    if user.CompanyID <= 0 {
        companyArg = nil
    } else {
        companyArg = user.CompanyID
    }
    query := `INSERT INTO users (email, password_hash, company_id, role) VALUES ($1, $2, $3, $4)`
    _, err := r.db.Exec(query, user.Email, user.PasswordHash, companyArg, user.Role)
    if err != nil {
        if pe, ok := err.(*pqx.Error); ok && string(pe.Code) == "23505" { // unique_violation
            return ErrEmailTaken
        }
        return err
    }
    return nil
}

var ErrEmailTaken = errors.New("email already exists")

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

func (r *repository) DeleteFCMTokenByValue(ctx context.Context, token string) error {
    _, err := r.db.ExecContext(ctx, `UPDATE users SET fcm_token = NULL WHERE fcm_token = $1`, token)
    return err
}

func (r *repository) GetAllUsers() ([]domain.User, error) {
    const query = `SELECT id, email, role, company_id FROM users ORDER BY id ASC`
    rows, err := r.db.Query(query)
    if err != nil { return nil, err }
    defer rows.Close()
    var users []domain.User
    for rows.Next() {
        var u domain.User
        if err := rows.Scan(&u.ID, &u.Email, &u.Role, &u.CompanyID); err != nil { return nil, err }
        users = append(users, u)
    }
    return users, nil
}

// GetFCMTokensByCompanyAllRoles returns all non-empty FCM tokens for users in a company,
// regardless of role. Useful when wanting to notify all members.
func (r *repository) GetFCMTokensByCompanyAllRoles(ctx context.Context, companyID int64) ([]string, error) {
    rows, err := r.db.QueryContext(ctx, `
        SELECT fcm_token
        FROM users
        WHERE company_id = $1 AND fcm_token IS NOT NULL AND fcm_token <> ''
    `, companyID)
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
