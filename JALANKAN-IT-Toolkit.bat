@echo off
title IT Support Toolkit
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0IT-Support-Toolkit.ps1"
if errorlevel 1 (
  echo.
  echo Toolkit ditutup atau terjadi error. Coba jalankan ulang sebagai Administrator.
  pause
)
