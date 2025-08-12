### **Panduan Setup dan Pengujian End-to-End**

Dokumen ini menjelaskan cara menjalankan seluruh ekosistem *microservice* CCTV Cerdas di lingkungan pengembangan lokal Anda menggunakan Docker.

## Prasyarat

Sebelum memulai, pastikan perangkat lunak berikut sudah terinstal di komputer Anda:

1.  **Docker Desktop:** Ini adalah komponen paling penting.
2.  **Git:** Untuk mengkloning repositori.
3.  **Terminal atau Command Prompt:** Seperti `cmd`, `PowerShell`, atau `Git Bash` di Windows.
4.  **`curl`:** Alat bantu untuk menguji API. (Biasanya sudah terinstal di Windows 10/11 dan macOS).

-----

## Langkah 1: Persiapan Lingkungan Docker (Hanya Satu Kali)

Langkah-langkah ini hanya perlu dilakukan sekali saat Anda pertama kali menyiapkan proyek di komputer baru.

#### A. Pastikan Docker Berjalan

Buka aplikasi **Docker Desktop**. Tunggu hingga ikon paus di *system tray* (pojok kanan bawah layar) berwarna **hijau stabil**. Ini menandakan Docker sudah sepenuhnya siap.

#### B. Buat Infrastruktur Bersama

Kita perlu membuat "jaringan kota" dan "lemari ajaib" yang akan digunakan bersama oleh semua layanan. Buka terminal dan jalankan dua perintah ini:

1.  **Buat Jaringan Docker:**
    ```bash
    docker network create cctv_network
    ```
2.  **Buat Volume Penyimpanan Docker:**
    ```bash
    docker volume create ingestion_uploads
    ```

-----

## Langkah 2: Menjalankan Seluruh Sistem

Dengan arsitektur terpadu, Anda hanya perlu **satu terminal** dan **satu perintah** untuk menyalakan seluruh pabrik.

1.  **Klone Repositori:** Jika belum, klone repositori utama yang berisi semua sub-proyek.
    ```bash
    # Ganti dengan URL repositori Anda
    git clone https://github.com/username/proyek-cctv-keseluruhan.git
    cd proyek-cctv-keseluruhan
    ```
2.  **Jalankan Docker Compose:** Perintah ini akan membangun *image* untuk setiap layanan (Go dan Python) dan menyalakan semua kontainer.
    ```bash
    docker-compose up --build
    ```
3.  **Tunggu dan Perhatikan Log:** Tunggu beberapa saat hingga semua layanan stabil dan berjalan. Anda akan melihat log dari `api_main`, `api_ingestion`, `ai_worker`, `db`, dll., muncul secara bersamaan di terminal Anda.

-----

## Langkah 3: Pengujian Alur Kerja Penuh (End-to-End)

Setelah semua layanan berjalan, mari kita simulasikan seluruh alur kerja dari awal hingga akhir.

#### A. Siapkan Data Uji (Inisialisasi)

Kita perlu mendaftarkan perusahaan, pengguna, dan kamera terlebih dahulu. Buka **terminal baru** untuk menjalankan perintah-perintah `curl` ini.

1.  **Buat Perusahaan Baru:**

    ```bash
    curl -X POST -H "Content-Type: application/json" -d "{\"name\":\"PT Uji Coba\"}" http://localhost:8080/api/companies
    ```

2.  **Daftarkan Admin Perusahaan:** (Gunakan `company_id` yang didapat dari langkah sebelumnya, biasanya `1`)

    ```bash
    curl -X POST -H "Content-Type: application/json" -d "{\"email\":\"admin@ujicoba.com\",\"password\":\"password123\",\"company_id\":1,\"role\":\"company_admin\"}" http://localhost:8080/api/register
    ```

3.  **Login untuk Mendapatkan Token:**

    ```bash
    curl -X POST -H "Content-Type: application/json" -d "{\"email\":\"admin@ujicoba.com\",\"password\":\"password123\"}" http://localhost:8080/api/login
    ```

    **Salin token JWT** yang Anda dapatkan dari respons ini.

4.  **Daftarkan Kamera:** (Ganti `TOKEN_ANDA_DISINI` dengan token yang baru Anda salin)

    ```bash
    curl -X POST -H "Authorization: Bearer TOKEN_ANDA_DISINI" -H "Content-Type: application/json" -d "{\"name\":\"Kamera Lobi Uji\"}" http://localhost:8080/api/cameras
    ```

#### B. Picu Deteksi Anomali

1.  **Siapkan Klip Video:** Buat sebuah file video pendek dan beri nama `force_anomaly_clip.mp4`. Letakkan file ini di direktori utama proyek Anda.

2.  **Kirim Video ke Backend Penerima:**

    ```bash
    curl -X POST -F "video_clip=@force_anomaly_clip.mp4" http://localhost:8081/ingest/video
    ```

#### C. Verifikasi Hasilnya

Kembali ke **terminal Docker utama Anda** dan perhatikan log yang muncul. Anda akan melihat jejak alur kerja yang lengkap:

1.  **`api_ingestion-1`** akan mencetak bahwa ia menerima file dan mengirim tugas ke RabbitMQ.
2.  **`ai_worker-1`** akan mencetak bahwa ia menerima tugas, mendeteksi anomali (karena nama file), dan mengirim laporan ke Backend Utama.
3.  **`api_main-1`** akan mencetak bahwa ia menerima laporan, menyimpannya ke database, dan memicu **simulasi notifikasi push**.

Jika Anda melihat semua log ini, selamat\! Anda telah berhasil menjalankan dan menguji seluruh sistem *microservice* Anda.