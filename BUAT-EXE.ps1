# BUAT-EXE.ps1 — Build versi .exe dari IT Support Toolkit via modul PS2EXE
#
# PERINGATAN PENTING (baca sebelum pakai):
# 1. Antivirus / Windows Defender HAMPIR PASTI menandai file .exe hasil PS2EXE
#    sebagai false-positive, karena pola ini juga dipakai malware sungguhan.
#    Siapkan exclusion di antivirus kantor Anda, atau tetap pakai versi .bat + .ps1
#    (rekomendasi utama).
# 2. Fitur file (Favorit, Kustom, Logs, posisi window) tetap berfungsi — lokasinya
#    mengikuti lokasi file .exe.
# 3. Jalankan script ini sekali di PC teknisi, lalu sebarkan HASIL .exe-nya.
#
# Cara pakai:
#   powershell -ExecutionPolicy Bypass -File BUAT-EXE.ps1            (build)
#   powershell -ExecutionPolicy Bypass -File BUAT-EXE.ps1 -Install   (pasang modul dulu)

param([switch]$Install)

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "Modul ps2exe belum terpasang." -ForegroundColor Yellow
    if (-not $Install) {
        Write-Host "Jalankan ulang dengan:  powershell -ExecutionPolicy Bypass -File BUAT-EXE.ps1 -Install"
        Write-Host "(butuh internet - modul diunduh dari PSGallery)"
        exit 1
    }
    try {
        Write-Host "Memasang modul ps2exe dari PSGallery..." -ForegroundColor Cyan
        Install-Module ps2exe -Scope CurrentUser -Force -Repository PSGallery
    } catch {
        Write-Host ("Gagal memasang modul: " + $_.Exception.Message) -ForegroundColor Red
        exit 1
    }
}

Import-Module ps2exe

$in  = Join-Path $PSScriptRoot 'IT-Support-Toolkit.ps1'
$out = Join-Path $PSScriptRoot 'IT-Support-Toolkit.exe'

if (-not (Test-Path $in)) { Write-Host "Script utama tidak ditemukan: $in" -ForegroundColor Red; exit 1 }

Write-Host "Membangun $out ..." -ForegroundColor Cyan
try {
    Invoke-ps2exe -inputFile $in -outputFile $out `
        -noConsole `
        -requireAdmin `
        -title 'IT Support Toolkit' `
        -description 'Kumpulan command IT Support Windows - cek & perbaiki sekali klik' `
        -company 'IT Support Toolkit' `
        -version '7.0.0.0'
    Write-Host ''
    Write-Host "SELESAI: $out" -ForegroundColor Green
    Write-Host 'Ingat: file .exe bisa kena false-positive antivirus - uji dulu di PC target.' -ForegroundColor Yellow
    Write-Host 'Rekomendasi utama tetap memakai JALANKAN-IT-Toolkit.bat (tanpa risiko AV).' -ForegroundColor Yellow
} catch {
    Write-Host ("Build gagal: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
