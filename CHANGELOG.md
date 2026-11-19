# CHANGELOG - IT Support Toolkit

Semua perubahan penting pada toolkit ini didokumentasikan di sini.

## v7.0 - Helpdesk Suite, HiDPI, Pencarian Lintas-Tab & Paritas Lintas Platform (2026-11-19)

### Fitur Baru (Windows, Linux & macOS)
- **Tiket Helpdesk Harian**: tambah *Clear Cache Microsoft Teams* (Classic & New Teams), *Clear Cache Browser (Chrome & Edge)* tanpa hapus bookmark/password, *Cek Status Aktivasi Microsoft Office* (`ospp.vbs`), *Perbaikan Cepat Microsoft Office (Quick Repair)*, dan *Cek Ukuran File OST/PST Outlook* (dengan peringatan mendekati batas 50 GB).
- **Paket Migrasi / Sebelum Install Ulang PC**: tambah *Winget: Export Daftar Aplikasi (JSON)*, *Winget: Import Daftar Aplikasi (JSON)*, *Backup Bookmark Chrome & Edge*, serta *Backup Daftar & Port Printer*.
- **Jaringan & Remote Lanjutan**: tambah *Cek IP Publik & Info ISP*, *Cek Status VPN & Adapter Virtual*, *Cek Sertifikat SSL/TLS Domain* (sisa hari kedaluwarsa), dan *Wake-on-LAN (Magic Packet UDP port 9)* di tab **Remote & LAN**.
- **Peningkatan UX GUI Windows**:
  - **Pencarian Lintas-Tab Terpadu**: kotak cari (`Ctrl+F` / `Ctrl+K`, `Esc` bersihkan) kini menggabungkan hasil dari seluruh tab ke tab `Hasil Cari (N)`.
  - **Preview Perintah di Dialog Konfirmasi Merah**: dialog konfirmasi tindakan berisiko menampilkan daftar perintah yang akan dieksekusi (input password dimasking `***`).
  - **Tombol Salin Tiket**: menyalin ringkasan diagnosa + info host/OS/waktu dalam format Markdown siap tempel ke Jira/Freshdesk/GLPI.
  - **Kontrol Zoom Font (`A-` / `A+`)**: atur ukuran font output Consolas 8–16 pt langsung dari toolbar.
  - **Dukungan HiDPI Asli**: `SetProcessDPIAware` + skala DPI dinamis dan toolbar berbasis `FlowLayoutPanel` agar tajam di layar 125%–150% tanpa tombol terpotong.
  - **Meteran `CPU | RAM` Docked Right**: menempel di sisi kanan status bar saat jendela diubah ukurannya atau dimaksimalkan.
- **Paritas Linux & macOS (58 perintah: 37 Linux, 21 macOS)**:
  - Tambah *Diagnosa Pintar + Rekomendasi* dan *Export Laporan Diagnosa (HTML)* untuk Linux dan macOS.
  - Tambah *Cek IP Publik & Speed Test (curl)*, *Cek Sertifikat SSL Domain*, *Layanan Systemd Gagal (failed)* di Linux, serta *Homebrew: Cek & Update Paket* dan *Homebrew: Bersihkan Cache* di macOS.
  - Dukungan `kustom.json` lintas platform lewat field opsional `"OS": "Windows" | "Linux" | "MacOS" | "All"`.

### Perbaikan Bug & Keamanan
- **WEB-Dashboard.ps1**: perbaiki eksekusi item `open` (`$item.Target`), filter keluar seluruh perintah `danger` dan perintah input interaktif demi keamanan, tambah dukungan `kustom.json`, perbaiki warna CSS tombol `.open`/`.danger`, dan perbarui tata letak 2 kolom responsif dengan tombol Salin & Bersihkan.
- **IT-Support-Toolkit.ps1**: perbaiki `UseMnemonic = $false` agar karakter `&` pada tombol dan status bar tampil utuh; perbaiki posisi tombol `Export/Import Setelan` agar tidak bertumpuk dengan `Batalkan`; perbaiki pengecekan layanan `Spooler` pada `Antrian Print` dan validasi hak admin pada `Scan Error Drive C`.
- **AUDIT-Perintah.ps1**: tambah validasi AST untuk semua skrip `.ps1` pendamping, validasi JSON `CONTOH-kustom.json`, pengecekan `bash -n` pada `JALANKAN-Linux-Mac.sh`, serta fallback aman bila `bash` tidak tersedia.

### Repositori & CI/CD
- Tambah `LICENSE` (MIT), `CONTRIBUTING.md`, `SECURITY.md`, template Issue GitHub, dan GitHub Actions CI (`.github/workflows/audit.yml`).

## v6.0 - Audit & Ekosistem Tim (2026-11-19)
- **AUDIT-Perintah.ps1**: alat audit ulang-pakai — parse-validate semua command PS tertanam,
  `bash -n` semua perintah Linux/macOS, `-RunChecks` menjalankan semua perintah CHECK headless
  dengan timeout, report ke `AUDIT-Report.txt`
- **BUAT-EXE.ps1**: build versi .exe via PS2EXE (opsional; perhatikan risiko false-positive antivirus)
- **WEB-Dashboard.ps1**: dashboard web lokal (127.0.0.1 + token) untuk diakses dari HP/PC lain
  saat merawat PC client; perintah danger tidak diekspos lewat web
- **Export/Import Setelan**: favorit + posisi window + kustom.json dikemas ke satu file zip
- **Kamus Error Windows** di tab Bantuan
- `$script:AppRoot` (fallback lokasi exe) agar fitur file tetap bekerja di versi .exe

## v5.0 - Super Edition (2026-11-19)
- Tab baru: **Remote & LAN** (Diagnosa PC Remote WinRM, aktifkan WinRM, Scan Perangkat LAN)
- **Kustom (Tim)**: perintah tim via `kustom.json` tanpa menyentuh kode
- **Mode Aman**: nonaktifkan semua tombol berisiko (untuk junior/client)
- **Riwayat Eksekusi**: daftar log lama -> buka di Notepad
- **Speed Test Internet** (Cloudflare), **Analisa Ruang Disk C:**, **Keping RAM**, **Product Key OEM**, **Advanced Startup/WinRE**
- **Maintenance Mingguan**: pasang/copot task otomatis AIO (Scheduled Tasks)
- **Laporan Diagnosa** naik kelas ke HTML
- Polish: single-instance (mutex), posisi window tersimpan (`posisi.json`), Ctrl+F/Esc

## v4.0 - Lintas Platform (2026-11-19)
- **Linux & macOS**: menu terminal interaktif via PowerShell Core (29 perintah Linux, 12 macOS)
- Deteksi OS otomatis: Windows = GUI, Linux/macOS = terminal
- Launcher `JALANKAN-Linux-Mac.sh` + panduan instalasi pwsh
- Auto-detect apt/dnf/zypper; Set IP Statik via nmcli; SMART; journalctl; user management

## v3.0 - Super Lengkap (2026-11-18)
- Tab **Ekstra**: sinkronisasi jam NTP, fix audio, power plan, driver bermasalah, USB, BSOD dump,
  pending reboot, file HOSTS
- Tab **User & Akun** diperluas: quser/qwinsta, logoff sesi, wajib ganti password, buat user,
  user -> admin, cek domain, Remote Desktop on/off
- Jaringan: Diagnosa Host Tertentu, Set IP Statik/DHCP, reset proxy, netstat, tes port,
  **lihat semua password WiFi**
- Laporan Diagnosa (TXT), pencarian perintah, klik-kanan salin perintah, tombol Buka Log

## v2.0 - Fitur Keselamatan & Diagnosa Pintar (2026-11-18)
- **Auto Restore Point** sebelum perintah berisiko; tombol **Batalkan** proses berjalan
- **Diagnosa Pintar + Rekomendasi** (analisa hasil otomatis)
- **Laporan Diagnosa**, tombol **Buka Log**, klik-kanan salin perintah
- Batalkan shutdown/CHKDSK terjadwal; shutdown diberi jeda 30 detik
- Pencarian perintah real-time + auto pindah tab

## v1.0 - Rilis Awal (2026-11-18)
- GUI WinForms 11 tab: Cepat, Jaringan, Sistem, Disk, Update, Printer, Keamanan,
  Bersih-Bersih, Ekstra, User & Akun, Utilitas
- 126 perintah cek & perbaiki; mesin eksekusi via batch tersembunyi + antrean otomatis
- Auto-elevasi Administrator; log otomatis ke folder `Logs\`
- Mode script `-List` / `-Run "nama"`
