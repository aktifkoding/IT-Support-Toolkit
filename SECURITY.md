# Kebijakan Keamanan

## Praktik Penggunaan Aman

IT Support Toolkit menjalankan perintah administrasi sistem dengan hak **Administrator** (Windows) atau **root/sudo** (Linux/macOS). Perhatikan poin berikut saat mengoperasikan toolkit di lingkungan produksi atau PC client:

1. **Dashboard Web Lokal (`WEB-Dashboard.ps1`)**
   - Server hanya mendengarkan di `127.0.0.1:8098` dengan token acak 12 karakter per sesi.
   - Seluruh perintah bertipe `danger` dan perintah yang membutuhkan input interaktif sengaja tidak diekspos lewat web.
   - Jika Anda membuka akses sementara dari HP/laptop lain di LAN menggunakan `netsh interface portproxy`, segera hapus aturan `portproxy` begitu sesi perawatan selesai:
     ```cmd
     netsh interface portproxy delete v4tov4 listenport=8098 listenaddress=0.0.0.0
     ```
   - Jangan pernah membuka port `8098` ke internet publik.

2. **Ekspor Profil WiFi (`Backup WiFi + Password`)**
   - Perintah `netsh wlan export profile key=clear` menyimpan kata sandi WiFi dalam bentuk teks terbuka (XML). Simpan berkas secara aman dan hapus segera setelah migrasi selesai.

3. **Mode Aman dan Auto Restore Point**
   - Gunakan **Mode Aman** saat toolkit dipinjamkan ke teknisi junior atau saat pendampingan client untuk menonaktifkan seluruh tombol merah.
   - Biarkan **Auto Restore Point** aktif agar titik rollback dibuat sebelum tindakan berisiko dijalankan.

4. **Konfigurasi Kustom (`kustom.json`)**
   - Berkas `kustom.json` dikecualikan di `.gitignore`. Pastikan tidak menyimpan kredensial plain-text atau path server rahasia di file yang di-commit ke Git.

## Pelaporan Kerentanan

Jika Anda menemukan celah keamanan (misalnya potensi command injection, kebocoran kredensial, atau bypass kontrol keamanan di `WEB-Dashboard.ps1` / `IT-Support-Toolkit.ps1`), silakan buka laporan melalui tab **Security Advisories** di repositori GitHub `aktifkoding/IT-Support-Toolkit` atau hubungi maintainer secara privat sebelum mempublikasikan detailnya.
