# CCTV Camera 2

Template ringan untuk menjadikan laptop teman sebagai sumber kamera yang langsung mengalirkan video ke stack CCTV utama di laptop Anda. Folder ini tidak menjalankan Docker; ia hanya memakai `ffmpeg` untuk mengirim ke MediaMTX (RTSP/RTMP) yang sudah berjalan di mesin pusat.

## Fitur
- Streaming webcam atau file video ke host pusat via RTSP (default) atau RTMP.
- Satu skrip Python ringan tanpa dependensi eksternal.
- Dukungan lintas platform (Windows, macOS, Linux) selama `ffmpeg` tersedia.
- Konfigurasi lewat argumen CLI atau file `.env`.

## Prasyarat Pada Laptop Teman
- Python 3.8 atau lebih baru.
- `ffmpeg` ada di PATH atau diletakkan di `cctv-camera-2/bin/ffmpeg`.
  - Windows: bisa unduh versi portable dari https://www.gyan.dev/ffmpeg/builds/.
  - macOS: `brew install ffmpeg`.
  - Linux (Ubuntu/Debian): `sudo apt install ffmpeg`.
- Untuk upload klip: `pip install -r requirements.txt` (requests + opencv-python).

## Persiapan Cepat
1. Salin folder `cctv-camera-2` ke laptop teman.
2. Duplikat `.env.example` menjadi `.env`, isi `HOST=10.68.111.149` (alamat LAN mesin pusat) dan `STREAM_KEY=<stream key yang diizinkan MediaMTX>` (misal `cam3`).
3. Jalankan perintah berikut (contoh Windows PowerShell):
   ```powershell
   cd cctv-camera-2
   python stream_client.py
   ```
   Contoh Linux/macOS:
   ```bash
   cd cctv-camera-2
   python3 stream_client.py
   ```
4. Beri izin firewall jika ada prompt. Stream akan muncul di MediaMTX host (`http://<HOST>:8888/<stream-key>/index.m3u8` untuk HLS).

## Argumen Utama
```bash
python stream_client.py --host 10.68.111.149 --stream-key cam3 --protocol rtmp --fps 25 --width 640 --height 360
```
- `--host`: IP atau hostname laptop pusat (wajib bila tidak di `.env`). Untuk setup ini gunakan `10.68.111.149`.
- `--stream-key`: default `cam3`. Sesuaikan dengan konfigurasi MediaMTX.
- `--protocol`: `rtsp` (default) atau `rtmp`.
- `--device`: nama perangkat (Windows), index (macOS), atau path `/dev/video` (Linux).
- `--source`: gunakan file/URL alih-alih webcam (`--source sample.mp4`).
- `--pixel-format`: paksa format pixel input (misal `nv12` / `yuyv422` dari hasil `ffmpeg -list_options`).
- `--list-devices`: hanya menampilkan daftar perangkat lalu keluar.
- `--dry-run`: tampilkan perintah `ffmpeg` tanpa menjalankannya.

Semua argumen memiliki padanan variabel lingkungan (`HOST`, `STREAM_KEY`, dll). Nilai dari `.env` akan menjadi default.

## Tips Device
- Windows: jalankan `python stream_client.py --list-devices`. Lalu gunakan nilai persis di kolom `Name` dengan `--device "Integrated Camera"`.
- macOS: `--list-devices` menampilkan index (contoh `0` untuk webcam internal). Gunakan `--device 0`.
- Linux: script akan menebak `/dev/video0`. Jika kamera berbeda, jalankan `ls /dev/video*` lalu set `--device /dev/video2`.
- Jika kamera menolak resolusi/FPS default, set `WIDTH=0`, `HEIGHT=0`, `FPS=0` agar ffmpeg memakai setting bawaan perangkat, atau tentukan kombinasi yang valid beserta `PIXEL_FORMAT` sesuai output `ffmpeg -f dshow -list_options true -i video="<Nama>"`.

## Mengirim Klip Ke Ingestion
1. Pastikan dependencies sudah terpasang: `pip install -r requirements.txt`.
2. Isi `.env` dengan:
   ```
   HOST=10.68.111.149
   CAMERA_ID=<angka dari hasil seeder (FRIEND_CAM_ID)>
   STREAM_KEY=<stream key yang sama dengan streaming>
   CLIP_SOURCE=rtmp://10.68.111.149:1935/<stream-key>  # atau rtsp://10.68.111.149:8554/<stream-key>
   ```
   Jika ingin memakai webcam langsung, kosongkan `CLIP_SOURCE`.
3. Jalankan:
   ```powershell
   python send_clips.py --ffmpeg-capture --no-preview
   ```
   Sesuaikan durasi `--seconds` bila perlu (default 8). Mode `--ffmpeg-capture` direkomendasikan untuk RTSP/RTMP.
4. Saat sukses, terminal menampilkan status HTTP 200 dari ingestion; AI worker di host akan menerima tugas baru.

**Catatan**
- `FFMPEG_CAPTURE=1` (default) merekam klip via ffmpeg CLI sehingga stabil di koneksi jaringan.
- Jika Anda merekam dari RTSP/RTMP yang sudah H.264, set `COPY_STREAM=1` atau tambahkan `--copy-stream` agar ffmpeg menyalin stream langsung (`-c copy`) sehingga hasil file tidak blank.
- Tambahkan `FORCE_ANOMALY=1` jika ingin menandai klip sebagai anomaly (debug end-to-end).
- Gunakan `CLIP_LOOP=1` bila ingin terus menerus mengirim klip (mis. untuk stress test).
- Atur `CLIP_INTERVAL=10` (detik) untuk memberi jeda antar klip saat loop. CLI juga mendukung `--loop` dan `--interval 15`.

## Mode File atau IP Camera
Jika teman Anda memiliki kamera IP atau file video:
```bash
python stream_client.py --host 10.68.111.149 --stream-key cam3 --source rtsp://ip-camera/stream1
```
Atau
```bash
python stream_client.py --host 10.68.111.149 --stream-key cam3 --source clip.mp4 --loop
```

## Mengirim Klip Ke Ingestion (Opsional)
Script ini hanya fokus ke live streaming. Untuk mengirim klip pendek ke ingestion service, gunakan `curl`:
```bash
curl -X POST "http://10.68.111.149:8081/ingest/video" \
  -F "camera_id=<ID>" \
  -F "video_clip=@clip.mp4"
```

## Troubleshooting
- **`ffmpeg` tidak ditemukan**: cek PATH atau letakkan binary di `bin/ffmpeg`.
- **Stream putus-putus**: coba `--protocol rtmp` karena lebih toleran di jaringan tidak stabil.
- **Tidak ada video**: pastikan stream key unik dan dummy publisher `test_publisher_cam3` di host pusat tidak sedang aktif.
- **Device tidak terlihat**: jalankan `--list-devices` (Windows/macOS) atau cek `ls /dev/video*` (Linux).
