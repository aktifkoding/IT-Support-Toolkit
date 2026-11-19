# CHANGELOG — IT Support Toolkit

Semua perubahan penting pada toolkit ini didokumentasikan di sini.

## v6.0 — Audit & Ekosistem Tim (2026-11-19)
- **AUDIT-Perintah.ps1**: alat audit ulang-pakai — parse-validate semua command PS tertanam,
  `bash -n` semua perintah Linux/macOS, `-RunChecks` menjalankan semua perintah CHECK headless
  dengan timeout, report ke `AUDIT-Report.txt`
- **BUAT-EXE.ps1**: build versi .exe via PS2EXE (opsional; perhatikan risiko false-positive antivirus)
- **WEB-Dashboard.ps1**: dashboard web lokal (127.0.0.1 + token) untuk diakses dari HP/PC lain
  saat merawat PC client; perintah danger tidak diekspos lewat web
- **Export/Import Setelan**: favorit + posisi window + kustom.json dikemas ke satu file zip
- **Kamus Error Windows** di tab Bantuan
- `$script:AppRoot` (fallback lokasi exe) agar fitur file tetap bekerja di versi .exe

## v5.0 — Super Edition (2026-11-19)
- Tab baru: **Remote & LAN** (Diagnosa PC Remote WinRM, aktifkan WinRM, Scan Perangkat LAN)
- **Kustom (Tim)**: perintah tim via `kustom.json` tanpa menyentuh kode
- **Mode Aman**: nonaktifkan semua tombol berisiko (untuk junior/client)
- **Riwayat Eksekusi**: daftar log lama → buka di Notepad
- **Speed Test Internet** (Cloudflare), **Analisa Ruang Disk C:**, **Keping RAM**, **Product Key OEM**, **Advanced Startup/WinRE**
- **Maintenance Mingguan**: pasang/copot task otomatis AIO (Scheduled Tasks)
- **Laporan Diagnosa** naik kelas ke HTML
- Polish: single-instance (mutex), posisi window tersimpan (`posisi.json`), Ctrl+F/Esc

## v4.0 — Lintas Platform (2026-11-19)
- **Linux & macOS**: menu terminal interaktif via PowerShell Core (29 perintah Linux, 12 macOS)
- Deteksi OS otomatis: Windows = GUI, Linux/macOS = terminal
- Launcher `JALANKAN-Linux-Mac.sh` + panduan instalasi pwsh
- Auto-detect apt/dnf/zypper; Set IP Statik via nmcli; SMART; journalctl; user management

## v3.0 — Super Lengkap (2026-11-18)
- Tab **Ekstra**: sinkronisasi jam NTP, fix audio, power plan, driver bermasalah, USB, BSOD dump,
  pending reboot, file HOSTS
- Tab **User & Akun** diperluas: quser/qwinsta, logoff sesi, wajib ganti password, buat user,
  user → admin, cek domain, Remote Desktop on/off
- Jaringan: Diagnosa Host Tertentu, Set IP Statik/DHCP, reset proxy, netstat, tes port,
  **lihat semua password WiFi**
- Laporan Diagnosa (TXT), pencarian perintah, klik-kanan salin perintah, tombol Buka Log

## v2.0 — Fitur Keselamatan & Diagnosa Pintar (2026-11-18)
- **Auto Restore Point** sebelum perintah berisiko; tombol **Batalkan** proses berjalan
- **Diagnosa Pintar + Rekomendasi** (analisa hasil otomatis)
- **Laporan Diagnosa**, tombol **Buka Log**, klik-kanan salin perintah
- Batalkan shutdown/CHKDSK terjadwal; shutdown diberi jeda 30 detik
- Pencarian perintah real-time + auto pindah tab

## v1.0 — Rilis Awal (2026-11-18)
- GUI WinForms 11 tab: Cepat, Jaringan, Sistem, Disk, Update, Printer, Keamanan,
  Bersih-Bersih, Ekstra, User & Akun, Utilitas
- 126 perintah cek & perbaiki; mesin eksekusi via batch tersembunyi + antrean otomatis
- Auto-elevasi Administrator; log otomatis ke folder `Logs\`
- Mode script `-List` / `-Run "nama"`
