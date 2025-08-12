package domain

type User struct {
	ID           int64
	Email        string `json:"email"`
	Password     string `json:"password"`
	PasswordHash string
	CompanyID    int64  `json:"company_id"`
	Role         string `json:"role"` // 'user' or 'company_admin'
}
