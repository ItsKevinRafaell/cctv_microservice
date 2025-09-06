package camera

import "cctv-main-backend/internal/domain"

type Service interface {
    RegisterCamera(camera *domain.Camera) (int64, error)
    GetCamerasForCompany(companyID int64) ([]domain.Camera, error)
    UpdateCamera(camera *domain.Camera) error
    DeleteCamera(cameraID int64, companyID int64) error
    UpdateCameraAdmin(camera *domain.Camera) error
    DeleteCameraAdmin(cameraID int64) error
}

type service struct {
	repo Repository
}

func NewService(repo Repository) Service {
	return &service{repo: repo}
}

func (s *service) RegisterCamera(camera *domain.Camera) (int64, error) {
	return s.repo.CreateCamera(camera)
}

func (s *service) GetCamerasForCompany(companyID int64) ([]domain.Camera, error) {
	return s.repo.GetCamerasByCompanyID(companyID)
}

func (s *service) UpdateCamera(camera *domain.Camera) error {
	return s.repo.UpdateCamera(camera)
}

func (s *service) DeleteCamera(cameraID int64, companyID int64) error {
    return s.repo.DeleteCamera(cameraID, companyID)
}

func (s *service) UpdateCameraAdmin(camera *domain.Camera) error {
    return s.repo.UpdateCameraAdmin(camera)
}

func (s *service) DeleteCameraAdmin(cameraID int64) error {
    return s.repo.DeleteCameraAdmin(cameraID)
}
