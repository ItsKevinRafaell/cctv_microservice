package anomaly

import (
	"cctv-main-backend/internal/domain"
	"cctv-main-backend/pkg/notifier"
)

type Service interface {
	SaveReport(report *domain.AnomalyReport) error
	FetchAllReportsByCompany(companyID int64) ([]domain.AnomalyReport, error)
}

type service struct {
	repo     Repository
	notifier notifier.Notifier
}

func NewService(repo Repository, notifier notifier.Notifier) Service {
	return &service{repo: repo, notifier: notifier}
}

func (s *service) SaveReport(report *domain.AnomalyReport) error {
	err := s.repo.CreateReport(report)
	if err != nil {
		return err
	}

	go s.notifier.Send(report)

	return nil
}

func (s *service) FetchAllReportsByCompany(companyID int64) ([]domain.AnomalyReport, error) {
	return s.repo.GetAllReportsByCompany(companyID)
}
