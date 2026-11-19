# Panduan Kontribusi

Terima kasih telah membantu mengembangkan **IT Support Toolkit**. Kontribusi sangat diterima, mulai dari perbaikan bug, penambahan perintah diagnosa/perbaikan untuk Windows, Linux, maupun macOS, hingga penyempurnaan dokumentasi.

## Alur Kontribusi

1. Fork repositori ini, lalu buat branch baru dari `main` (misalnya `feat/perintah-vpn` atau `fix/spooler-check`).
2. Lakukan perubahan pada berkas terkait.
3. Jalankan audit otomatis sebelum commit:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\AUDIT-Perintah.ps1
   ```
   Di Linux/macOS (via PowerShell Core):
   ```bash
   pwsh -NoProfile -File ./AUDIT-Perintah.ps1
   ```
4. Pastikan hasil audit menunjukkan `masalah: 0`.
5. Buat Pull Request dengan penjelasan singkat tujuan perubahan dan langkah pengujiannya.

## Format Menambah Perintah Baru

### Katalog Windows (`$Categories` di `IT-Support-Toolkit.ps1`)

```powershell
@{
    Name = 'Nama Perintah'
    Desc = 'Ringkasan singkat (baris ke-2 pada tombol)'
    Type = 'check'  # check | fix | danger | open
    Cmds = @(
        'ipconfig /flushdns'
    )
    Note = 'Catatan opsional setelah perintah selesai.'
}
```

- Gunakan `Type = 'danger'` untuk setiap perintah yang menghapus data permanen, mengubah konfigurasi jaringan statik, memodifikasi akun/password, atau me-restart sistem.
- Untuk perintah yang membuka panel/aplikasi, gunakan `Type = 'open'` dan properti `Target` (bukan `Cmds`).
- Untuk perintah dengan input pengguna, definisikan `Input` dan `Build`, serta set `Password = $true` untuk kolom kata sandi agar nilainya dimasking di dialog preview.

### Katalog Linux & macOS (`$CategoriesNix` di `IT-Support-Toolkit.ps1`)

- Pastikan seluruh perintah shell kompatibel dengan `bash -n` (bebas error sintaks) dan menangani absennya tool opsional dengan fallback yang jelas (`2>/dev/null || echo "..."`).
- Jangan gunakan CRLF di `JALANKAN-Linux-Mac.sh` (dijaga oleh `.gitattributes`).

### Perintah Kustom Tim (Tanpa Mengubah Kode Inti)

Untuk perintah internal perusahaan yang spesifik ke infrastruktur lokal, gunakan `kustom.json` (salin dari `CONTOH-kustom.json`). Jangan commit data internal perusahaan ke repositori publik.
