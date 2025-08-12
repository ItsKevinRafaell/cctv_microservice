package user

import (
	"cctv-main-backend/internal/domain"
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

var jwtSecret = []byte("kunci-rahasia-yang-sangat-aman-dan-panjang")

type Service interface {
	Register(user *domain.User) error
	Login(input *domain.User) (string, error)
	FindUsersByCompany(companyID int64) ([]domain.User, error)
	UpdateRole(userID, companyID int64, role string) error
	Delete(userID, companyID int64) error
}

type service struct {
	repo Repository
}

func NewService(repo Repository) Service {
	return &service{repo: repo}
}

func (s *service) Login(input *domain.User) (string, error) {
	user, err := s.repo.GetUserByEmail(input.Email)
	if err != nil {
		return "", errors.New("email atau password salah")
	}

	err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(input.Password))
	if err != nil {
		return "", errors.New("email atau password salah")
	}

	claims := jwt.MapClaims{
		"user_id":    user.ID,
		"email":      user.Email,
		"company_id": user.CompanyID,
		"role":       user.Role,
		"exp":        time.Now().Add(time.Hour * 72).Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(jwtSecret)
	if err != nil {
		return "", err
	}

	return tokenString, nil
}

func (s *service) Register(user *domain.User) error {
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(user.Password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	user.PasswordHash = string(hashedPassword)
	return s.repo.CreateUser(user)
}

func (s *service) FindUsersByCompany(companyID int64) ([]domain.User, error) {
	return s.repo.GetUsersByCompanyID(companyID)
}

func (s *service) UpdateRole(userID, companyID int64, role string) error {
	return s.repo.UpdateUserRole(userID, companyID, role)
}

func (s *service) Delete(userID, companyID int64) error {
	return s.repo.DeleteUser(userID, companyID)
}
