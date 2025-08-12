# Tahap 1: Build - Menggunakan image Go untuk mengkompilasi aplikasi kita
FROM golang:1.24-alpine AS builder

# Set direktori kerja di dalam kontainer
WORKDIR /app

# Salin file manajemen modul
COPY go.mod ./
COPY go.sum ./

# Unduh semua dependensi
RUN go mod download

# Salin semua sisa kode sumber
COPY . .

# Kompilasi aplikasi.
# CGO_ENABLED=0 penting untuk build statis.
# -o /app/main akan menghasilkan file binary bernama 'main'
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/main ./cmd/api

# ---

# Tahap 2: Run - Menggunakan image minimal yang bersih untuk menjalankan aplikasi
FROM alpine:latest

# Set direktori kerja
WORKDIR /app

# Salin HANYA file binary yang sudah dikompilasi dari tahap 'builder'
COPY --from=builder /app/main .

# Expose port 8080 agar bisa diakses dari luar kontainer
EXPOSE 8080

# Perintah untuk menjalankan aplikasi saat kontainer dimulai
CMD ["./main"]