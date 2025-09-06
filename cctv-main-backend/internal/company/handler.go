package company

import (
	"cctv-main-backend/internal/domain"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
)

type Handler struct {
	service Service
}

func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) CreateCompany(w http.ResponseWriter, r *http.Request) {
	var company domain.Company
	if err := json.NewDecoder(r.Body).Decode(&company); err != nil {
		http.Error(w, "Request body tidak valid", http.StatusBadRequest)
		return
	}

	companyID, err := h.service.Create(&company)
	if err != nil {
		http.Error(w, "Gagal membuat perusahaan", http.StatusInternalServerError)
		return
	}

	response := map[string]int64{"company_id": companyID}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(response)
}

func (h *Handler) GetAllCompanies(w http.ResponseWriter, r *http.Request) {
	companies, err := h.service.FindAll()
	if err != nil {
		http.Error(w, "Gagal mengambil data perusahaan", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(companies)
}

func (h *Handler) UpdateCompany(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(r.URL.Path, "/")
	id, _ := strconv.ParseInt(parts[len(parts)-1], 10, 64)

	var company domain.Company
	if err := json.NewDecoder(r.Body).Decode(&company); err != nil {
		http.Error(w, "Request body tidak valid", http.StatusBadRequest)
		return
	}
	company.ID = id

	if err := h.service.Update(&company); err != nil {
		http.Error(w, "Perusahaan tidak ditemukan", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Perusahaan berhasil diperbarui."))
}

func (h *Handler) DeleteCompany(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(r.URL.Path, "/")
	id, _ := strconv.ParseInt(parts[len(parts)-1], 10, 64)

	if err := h.service.Delete(id); err != nil {
		http.Error(w, "Perusahaan tidak ditemukan", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Perusahaan berhasil dihapus."))
}
