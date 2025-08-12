# Proyek CCTV Cerdas Berbasis Microservice

Selamat datang di Proyek CCTV Cerdas. Ini adalah sebuah platform *backend* yang dirancang untuk menerima, menganalisis, dan melaporkan kejadian anomali dari kamera CCTV secara *real-time*. Sistem ini dibangun di atas arsitektur *microservice* yang modern, skalabel, dan tangguh, menggunakan Go untuk layanan backend dan Python untuk analisis AI.

##  Arsitektur Sistem

Sistem ini terdiri dari beberapa layanan independen yang berkomunikasi melalui jaringan internal Docker. Setiap layanan memiliki tanggung jawab yang spesifik untuk memastikan efisiensi dan skalabilitas.

[Image of a microservice architecture diagram]

#### 1. Backend Utama (`cctv-main-backend`)
Ini adalah "otak" dan "kantor pusat" dari seluruh sistem.
* **Tugas:** Mengelola logika bisnis, autentikasi, otorisasi, dan data.
* **Fitur:**
    * Manajemen Perusahaan & Pengguna (CRUD Penuh).
    * Sistem Login & Registrasi dengan token JWT.
    * Manajemen Kamera (CRUD).
    * Menerima dan menyimpan hasil laporan anomali.
    * Menyediakan API yang aman untuk aplikasi *frontend* (Flutter).
* **Teknologi:** Go, PostgreSQL.

#### 2. Backend Penerima (`cctv-ingestion-service`)
Ini adalah "pintu gerbang" atau "area bongkar muat" yang bertugas menerima data mentah dari lapangan.
* **Tugas:** Menerima unggahan klip video dari kamera.
* **Fitur:**
    * Menyimpan klip video ke *object storage* (MinIO).
    * Membuat dan mengirimkan pesan tugas analisis ke RabbitMQ.
* **Teknologi:** Go.

#### 3. AI Worker (`cctv-ai-worker`)
Ini adalah "departemen analis" yang melakukan pekerjaan berat.
* **Tugas:** Menganalisis klip video untuk mendeteksi anomali.
* **Fitur:**
    * Mendengarkan tugas baru dari antrian RabbitMQ.
    * Memuat model Machine Learning (`.h5`).
    * Memproses video, melakukan prediksi, dan menerjemahkan hasilnya.
    * Melaporkan hasil analisis ke Backend Utama.
* **Teknologi:** Python, TensorFlow, OpenCV.

#### 4. Infrastruktur Pendukung
* **Database (`PostgreSQL`):** Menyimpan semua data terstruktur (perusahaan, pengguna, kamera, laporan).
* **Antrian Tugas (`RabbitMQ`):** Bertindak sebagai "papan pengumuman" yang menghubungkan Backend Penerima dan AI Worker, memastikan tidak ada tugas yang hilang.
* **Penyimpanan File (`MinIO`):** "Gudang" untuk menyimpan semua aset file (klip video), kompatibel dengan API S3.

## Teknologi Utama
* **Backend:** Go (Golang)
* **Machine Learning:** Python, TensorFlow, OpenCV
* **Database:** PostgreSQL
* **Message Broker:** RabbitMQ
* **Object Storage:** MinIO (S3 Compatible)
* **Containerization & Orchestration:** Docker & Docker Compose