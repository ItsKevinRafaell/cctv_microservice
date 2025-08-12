package anomaly

import (
	"cctv-main-backend/internal/domain"
	"cctv-main-backend/pkg/notifier"
	"context"
	"log"
)

type Service interface {
	SaveReport(report *domain.AnomalyReport) error
	FetchAllReportsByCompany(companyID int64) ([]domain.AnomalyReport, error)
	ListRecent(companyID int64, limit int) ([]domain.AnomalyReport, error)
}

type service struct {
	repo     Repository
	notifier notifier.Notifier
}

func NewService(repo Repository, notifier notifier.Notifier) Service {
	return &service{repo: repo, notifier: notifier}
}

func (s *service) SaveReport(report *domain.AnomalyReport) error {
	if err := s.repo.CreateReport(report); err != nil {
		return err
	}

	// 2) Kirim notifikasi (sinkron agar jelas terlihat di log)
	if s.notifier != nil {
		if err := s.notifier.NotifyAnomaly(context.Background(), report); err != nil {
			log.Printf("NotifyAnomaly error: %v", err)
			// tidak return error supaya penyimpanan tetap dianggap sukses
		}
	} else {
		log.Println("NotifyAnomaly skip: notifier nil")
	}
	return nil
}

func (s *service) FetchAllReportsByCompany(companyID int64) ([]domain.AnomalyReport, error) {
	return s.repo.GetAllReportsByCompany(companyID)
}

func (s *service) ListRecent(companyID int64, limit int) ([]domain.AnomalyReport, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	return s.repo.GetRecentReportsByCompany(companyID, limit)
}
