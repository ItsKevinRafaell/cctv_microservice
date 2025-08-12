package company

import "cctv-main-backend/internal/domain"

type Service interface {
	Create(company *domain.Company) (int64, error)
	FindAll() ([]domain.Company, error)
	Update(company *domain.Company) error
	Delete(companyID int64) error
}

type service struct {
	repo Repository
}

func NewService(repo Repository) Service {
	return &service{repo: repo}
}

func (s *service) Create(company *domain.Company) (int64, error) {
	return s.repo.CreateCompany(company)
}

func (s *service) FindAll() ([]domain.Company, error) {
	return s.repo.GetAllCompanies()
}

func (s *service) Update(company *domain.Company) error {
	return s.repo.UpdateCompany(company)
}

func (s *service) Delete(companyID int64) error {
	return s.repo.DeleteCompany(companyID)
}
