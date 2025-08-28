package domain

type User struct {
	ID           int64
	Email        string `json:"email"`
	Password     string `json:"password"`
	PasswordHash string
	CompanyID    int64  `json:"company_id"`
    Role         string `json:"role"`                // 'user' | 'company_admin' | 'superadmin'
	FCMToken     string `json:"fcm_token,omitempty"` // Untuk menyimpan token FCM
}
