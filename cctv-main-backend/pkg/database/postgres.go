package database

import (
	"database/sql"
	"log"

	_ "github.com/lib/pq"
)

func NewConnection() *sql.DB {
	connStr := "host=db port=5432 user=admin password=secret dbname=cctv_db sslmode=disable"
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		log.Fatalf("Gagal terhubung ke database: %v", err)
	}

	if err = db.Ping(); err != nil {
		log.Fatalf("Tidak bisa ping ke database: %v", err)
	}

	log.Println("✅ Berhasil terhubung ke database PostgreSQL!")
	return db
}

func Migrate(db *sql.DB) {
	createCompaniesTable := `
	CREATE TABLE IF NOT EXISTS companies (
		id SERIAL PRIMARY KEY,
		name VARCHAR(255) NOT NULL,
		created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
	);`
	if _, err := db.Exec(createCompaniesTable); err != nil {
		log.Fatalf("Gagal membuat tabel companies: %v", err)
	}
	log.Println("   > Tabel 'companies' siap digunakan.")

	createUsersTable := `
	CREATE TABLE IF NOT EXISTS users (
		id SERIAL PRIMARY KEY,
		email VARCHAR(255) UNIQUE NOT NULL,
		password_hash VARCHAR(255) NOT NULL,
		company_id INTEGER REFERENCES companies(id) ON DELETE CASCADE,
		role VARCHAR(50) NOT NULL DEFAULT 'user', -- 'user' atau 'company_admin'
		fcm_token VARCHAR(255), -- Untuk menyimpan token FCM
		created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
	);`
	if _, err := db.Exec(createUsersTable); err != nil {
		log.Fatalf("Gagal membuat tabel users: %v", err)
	}
	log.Println("   > Tabel 'users' siap digunakan.")

	createCamerasTable := `
	CREATE TABLE IF NOT EXISTS cameras (
		id SERIAL PRIMARY KEY,
		name VARCHAR(255) NOT NULL,
		location VARCHAR(255),
		company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
		created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
	);`
	if _, err := db.Exec(createCamerasTable); err != nil {
		log.Fatalf("Gagal membuat tabel cameras: %v", err)
	}
	log.Println("   > Tabel 'cameras' siap digunakan.")

	createAnomalyTable := `
	CREATE TABLE IF NOT EXISTS anomaly_reports (
		id SERIAL PRIMARY KEY,
		camera_id INTEGER NOT NULL REFERENCES cameras(id) ON DELETE CASCADE,
		anomaly_type VARCHAR(50) NOT NULL,
		confidence FLOAT NOT NULL,
		video_clip_url TEXT, -- Untuk menyimpan link video bukti
		reported_at TIMESTAMP WITH TIME ZONE NOT NULL
	);`
	if _, err := db.Exec(createAnomalyTable); err != nil {
		log.Fatalf("Gagal membuat tabel anomaly_reports: %v", err)
	}
	log.Println("   > Tabel 'anomaly_reports' siap digunakan.")
}
