#!/usr/bin/env bash
# IT Support Toolkit - Launcher Linux & macOS
# Butuh PowerShell Core (pwsh): https://aka.ms/powershell
#   Linux : sudo snap install powershell --classic  |  atau lihat aka.ms/powershell
#   macOS : brew install --cask powershell
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v pwsh >/dev/null 2>&1; then
  echo "PowerShell (pwsh) belum terpasang di sistem ini."
  echo ""
  echo "Cara pasang:"
  echo "  Linux : sudo snap install powershell --classic"
  echo "          (atau ikuti panduan: https://aka.ms/powershell)"
  echo "  macOS : brew install --cask powershell"
  echo ""
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Info: banyak perintah butuh hak admin. Untuk hasil penuh jalankan:"
  echo "  sudo pwsh -NoProfile -File \"$DIR/IT-Support-Toolkit.ps1\""
  echo ""
  echo "Menjalankan tanpa sudo (perintah terbatas)..."
  sleep 2
  pwsh -NoProfile -File "$DIR/IT-Support-Toolkit.ps1"
else
  pwsh -NoProfile -File "$DIR/IT-Support-Toolkit.ps1"
fi
