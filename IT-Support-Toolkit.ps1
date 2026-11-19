param(
    [switch]$List,
    [string]$Run
)

# ---------------------------------------------------------------------
# DETEKSI PLATFORM: Windows / Linux / MacOS
# Windows  -> GUI WinForms (katalog lengkap Windows)
# Linux/MacOS -> menu terminal (butuh PowerShell Core / pwsh)
# ---------------------------------------------------------------------
$osPlatform = 'Windows'
if ($PSVersionTable.PSEdition -eq 'Core') {
    if ($IsLinux)     { $osPlatform = 'Linux' }
    elseif ($IsMacOS) { $osPlatform = 'MacOS' }
}
# Hook untuk pengujian lintas-platform dari mesin Windows (tidak didokumentasikan)
if ($env:ITTK_FORCE_OS -in @('Windows', 'Linux', 'MacOS')) { $osPlatform = $env:ITTK_FORCE_OS }

# --- Lokasi aplikasi (fallback utk versi EXE hasil PS2EXE yang kehilangan $PSScriptRoot) ---
$script:AppRoot = $PSScriptRoot
if (-not $script:AppRoot) {
    try { $script:AppRoot = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) } catch { $script:AppRoot = (Get-Location).Path }
}
$mainName = if (Test-Path (Join-Path $script:AppRoot 'IT-Support-Toolkit.ps1')) { 'IT-Support-Toolkit.ps1' } else { 'IT-Support-Toolkit.exe' }
$script:ScriptPath = Join-Path $script:AppRoot $mainName

function Remove-Emoji {
    # Emoji tidak stabil di GDI WinForms & beberapa terminal -> bersihkan dari teks UI
    param([string]$s)
    return ($s -replace '[\uD800-\uDBFF][\uDC00-\uDFFF]', '' -replace '[\u2000-\u2BFF\uFE0F]', '').Trim()
}

# =====================================================================
#  IT SUPPORT TOOLKIT v1.0
#  Kumpulan command IT Support Windows - tinggal klik, langsung jalan.
#  Cek (diagnosa) & Perbaiki (fix): jaringan, sistem, disk, windows
#  update, printer, keamanan, bersih-bersih, user & utilitas.
#
#  Cara pakai   : double-click JALANKAN-IT-Toolkit.bat
#  Mode script  : -List (daftar perintah) / -Run "nama" (tanpa GUI)
#  Butuh        : Windows 10/11 + PowerShell 5.1, sebagai Administrator
# =====================================================================

# ---------------------------------------------------------------------
# KATALOG PERINTAH
# Type : check  = cek/diagnosa (aman)
#        fix    = perbaikan (langsung dieksekusi)
#        danger = berisiko (muncul konfirmasi dulu)
#        open   = buka aplikasi / panel Windows
# ---------------------------------------------------------------------
$Categories = @(
    @{
        Key   = 'fav'
        Title = '⭐ Favorit'
        Items = @()
    }
    @{
        Key   = 'quick'
        Title = '🚀 Cepat'
        Intro = 'Biru = Cek  •  Oranye = Perbaiki  •  Merah = Berisiko (minta konfirmasi)  •  Hijau = Buka aplikasi'
        Items = @(
            @{
                Name = '🤖 AIO: Cek & Perbaiki Cepat'
                Desc = 'Diagnosa jaringan + flush DNS + winsock + bersih temp + spooler + Defender'
                Type = 'fix'
                Cmds = @(
                    'ipconfig /all'
                    'ping 8.8.8.8 -n 4'
                    'ipconfig /flushdns'
                    'netsh winsock reset'
                    'del /f /s /q "%TEMP%\*"'
                    'for /d %%d in ("%TEMP%\*") do rd /s /q "%%d"'
                    'del /f /s /q "%SystemRoot%\Temp\*"'
                    'for /d %%d in ("%SystemRoot%\Temp\*") do rd /s /q "%%d"'
                    'net stop spooler'
                    'net start spooler'
                    'powershell -NoProfile -Command "Update-MpSignature -ErrorAction SilentlyContinue"'
                )
                Note = 'DIREKOMENDASIKAN RESTART PC setelah AIO selesai agar reset winsock berlaku penuh.'
            }
            @{
                Name = '🌐 Diagnosa Jaringan Cepat'
                Desc = 'Info IP lengkap + tes ping + tes DNS'
                Type = 'check'
                Cmds = @(
                    'ipconfig /all'
                    'ping 8.8.8.8 -n 4'
                    'nslookup google.com'
                )
            }
            @{
                Name = '🏥 Repair Windows Lengkap (DISM + SFC)'
                Desc = 'Perbaiki image & file sistem Windows - butuh internet'
                Type = 'fix'
                Cmds = @(
                    'dism /online /cleanup-image /checkhealth'
                    'dism /online /cleanup-image /scanhealth'
                    'dism /online /cleanup-image /restorehealth'
                    'sfc /scannow'
                )
                Note = 'Proses 15-60 menit. RESTART PC setelah selesai. Jangan tutup/ubah status bar.'
            }
            @{
                Name = '🧹 Bersih-Bersih Cepat'
                Desc = 'Hapus temp user + temp Windows + prefetch + recycle bin'
                Type = 'danger'
                Cmds = @(
                    'del /f /s /q "%TEMP%\*"'
                    'for /d %%d in ("%TEMP%\*") do rd /s /q "%%d"'
                    'del /f /s /q "%SystemRoot%\Temp\*"'
                    'for /d %%d in ("%SystemRoot%\Temp\*") do rd /s /q "%%d"'
                    'del /f /s /q "%SystemRoot%\Prefetch\*"'
                    'powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue; Write-Host ''Recycle Bin dikosongkan.'' "'
                )
                Note = 'File terhapus permanen (Recycle Bin ikut dikosongkan). File yang dipakai aplikasi akan tertinggal - normal.'
            }
            @{
                Name = '📋 Cek Kesehatan PC (Ringkas)'
                Desc = 'Uptime, RAM, drive, kesehatan disk, Defender, update terakhir'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "$os = Get-CimInstance Win32_OperatingSystem; Write-Host (''Boot terakhir : '' + $os.LastBootUpTime); Write-Host (''Uptime        : '' + ((Get-Date) - $os.LastBootUpTime).ToString())"'
                    'powershell -NoProfile -Command "$os = Get-CimInstance Win32_OperatingSystem; Write-Host (''RAM terpasang : '' + [math]::Round($os.TotalVisibleMemorySize/1MB,1) + '' GB''); Write-Host (''RAM bebas     : '' + [math]::Round($os.FreePhysicalMemory/1MB,1) + '' GB'')"'
                    'powershell -NoProfile -Command "Get-Volume | Where-Object DriveLetter | Format-Table DriveLetter,FileSystemLabel,@{n=''FreeGB'';e={[math]::Round($_.SizeRemaining/1GB,1)}},@{n=''TotalGB'';e={[math]::Round($_.Size/1GB,1)}},HealthStatus -AutoSize"'
                    'powershell -NoProfile -Command "Get-PhysicalDisk | Format-Table FriendlyName,HealthStatus,OperationalStatus,MediaType -AutoSize"'
                    'powershell -NoProfile -Command "Get-MpComputerStatus | Format-List AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureLastUpdated"'
                    'powershell -NoProfile -Command "Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 5 HotFixID,Description,InstalledOn | Format-Table -AutoSize"'
                )
            }
            @{
                Name = '🧠 Diagnosa Pintar + Rekomendasi'
                Desc = 'Cek internet/DNS/disk/Defender, lalu dianalisa otomatis'
                Type = 'check'
                Cmds = @(
                    'echo ===MGW==='
                    'powershell -NoProfile -Command "$gw = (Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Sort-Object RouteMetric | Select-Object -First 1).NextHop; if (-not $gw) { Write-Host ''Gateway tidak ditemukan'' } else { Write-Host (''Gateway : '' + $gw); ping $gw -n 4 }"'
                    'echo ===MNET==='
                    'ping 8.8.8.8 -n 10'
                    'echo ===MDNS==='
                    'nslookup google.com'
                    'echo ===MDISK==='
                    'powershell -NoProfile -Command "Get-Volume | Where-Object DriveLetter | Format-Table DriveLetter,FileSystemLabel,FileSystem,@{n=''FreeGB'';e={[math]::Round($_.SizeRemaining/1GB,1)}},@{n=''TotalGB'';e={[math]::Round($_.Size/1GB,1)}},HealthStatus -AutoSize"'
                    'powershell -NoProfile -Command "$v = Get-Volume -DriveLetter C -ErrorAction SilentlyContinue; if ($v) { Write-Host (''CFREE='' + [math]::Round($v.SizeRemaining/1GB,1)) } else { Write-Host ''CFREE=?'' }"'
                    'echo ===MDEF==='
                    'powershell -NoProfile -Command "Get-MpComputerStatus | Format-List AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureLastUpdated"'
                    'echo ===MUP==='
                    'powershell -NoProfile -Command "$os = Get-CimInstance Win32_OperatingSystem; Write-Host (''Uptime : '' + ((Get-Date) - $os.LastBootUpTime).ToString())"'
                )
                Analysis = {
                    param($Text)
                    $recs = @()
                    $seg = @{}
                    $cur = '_'
                    foreach ($line in ($Text -split "`r`n|`n")) {
                        if ($line -match '===M([A-Z]+)===') { $cur = $Matches[1]; if (-not $seg.ContainsKey($cur)) { $seg[$cur] = '' }; continue }
                        if ($seg.ContainsKey($cur)) { $seg[$cur] += $line + "`n" }
                    }
                    $gw   = [string]$seg['GW']
                    $net  = [string]$seg['NET']
                    $dns  = [string]$seg['DNS']
                    $disk = [string]$seg['DISK']
                    $def  = [string]$seg['DEF']
                    $up   = [string]$seg['UP']
                    if ($gw -match 'Gateway tidak ditemukan') {
                        $recs += 'Gateway tidak terdeteksi: WiFi/LAN tidak tersambung - cek "Info IP & Adapter Lengkap" (tab Jaringan) dan sambungkan koneksi dulu.'
                    } elseif ($gw -match '100% loss|Lost = [1-4]|transmit failed|could not find host|general failure') {
                        $recs += 'Gateway/router tidak menjawab: cek kabel LAN/WiFi, restart router/modem, atau coba "Restart Semua Adapter Jaringan" (tab Jaringan).'
                    } elseif ($net -match '100% loss|Lost = [1-8]|transmit failed|could not find host|general failure') {
                        $recs += 'Gateway OK tapi internet mati: coba "Perbarui IP (Release + Renew)" lalu "Restart Semua Adapter Jaringan". Kalau tetap gagal = masalah ISP/modem.'
                    }
                    if ($dns -match 'timed out|no servers could|no response from server|server can.t find|default servers are not available|unknown host') {
                        $recs += 'DNS gagal resolve: jalankan "Set DNS Google (8.8.8.8)" (tab Jaringan), lalu tes DNS lagi.'
                    }
                    if ($disk -match 'CFREE=([\d.]+)') {
                        $free = [double]$Matches[1]
                        if ($free -lt 15) { $recs += ('Drive C sisa ' + $free + ' GB (kritis, sehatnya >15 GB): jalankan "Bersih-Bersih Cepat" atau buka Storage Sense (tab Bersih-Bersih).') }
                    }
                    if ($def -match 'RealTimeProtectionEnabled\s*:\s*False') {
                        $recs += 'Real-time protection Defender MATI: jalankan "Aktifkan Real-Time Protection" dan "Update Definisi Virus Defender" (tab Keamanan).'
                    }
                    if ($up -match 'Uptime.*?(\d+)\.(\d+):(\d+):') {
                        $d = [int]$Matches[1]
                        if ($d -ge 14) { $recs += ('PC menyala ' + $d + ' hari tanpa restart: disarankan restart untuk menyegarkan RAM & layanan Windows.') }
                    }
                    if ($recs.Count -eq 0) { $recs += 'Semua hasil normal - tidak ada masalah terdeteksi dari diagnosa ini.' }
                    $recs
                }
                Note = 'Bagian REKOMENDASI di bawah hasil adalah saran tombol perbaikan yang bisa langsung diklik.'
            }
            @{
                Name = '📄 Buat Laporan Diagnosa (Export)'
                Desc = 'Kumpulkan data PC lengkap, simpan TXT di Desktop'
                Type = 'check'
                Cmds = @(
                    'reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName'
                    'reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v DisplayVersion'
                    'reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber'
                    'reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v UBR'
                    'systeminfo'
                    'powershell -NoProfile -Command "Get-CimInstance Win32_ComputerSystem | Format-List Manufacturer,Model,TotalPhysicalMemory"'
                    'powershell -NoProfile -Command "Get-CimInstance Win32_Processor | Format-List Name,NumberOfCores,NumberOfLogicalProcessors"'
                    'powershell -NoProfile -Command "Get-CimInstance Win32_VideoController | Format-List Name,DriverVersion,Status"'
                    'powershell -NoProfile -Command "Get-Volume | Where-Object DriveLetter | Format-Table DriveLetter,FileSystemLabel,@{n=''FreeGB'';e={[math]::Round($_.SizeRemaining/1GB,1)}},@{n=''TotalGB'';e={[math]::Round($_.Size/1GB,1)}},HealthStatus -AutoSize"'
                    'powershell -NoProfile -Command "Get-PhysicalDisk | Format-Table FriendlyName,HealthStatus,MediaType -AutoSize"'
                    'powershell -NoProfile -Command "Get-MpComputerStatus | Format-List AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureLastUpdated"'
                    'powershell -NoProfile -Command "Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 15 HotFixID,Description,InstalledOn | Format-Table -AutoSize"'
                    'ipconfig /all'
                    'powershell -NoProfile -Command "Get-WinEvent -FilterHashtable @{LogName=''System'';Level=2} -MaxEvents 15 -ErrorAction SilentlyContinue | Format-List TimeCreated,ProviderName,Id,Message"'
                    'powershell -NoProfile -Command "Get-CimInstance Win32_StartupCommand | Format-Table Name,Command,Location,User -AutoSize -Wrap"'
                )
                PostRun = {
                    param($Text)
                    $desk = [Environment]::GetFolderPath('Desktop')
                    $path = Join-Path $desk ('Laporan-Diagnosa-{0}-{1:yyyyMMdd-HHmm}.html' -f $env:COMPUTERNAME, (Get-Date))
                    $esc  = $Text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
                    $meta = 'PC: ' + $env:COMPUTERNAME + ' &nbsp;&bull;&nbsp; User: ' + $env:USERNAME + ' &nbsp;&bull;&nbsp; Tanggal: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                    $html = '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Laporan Diagnosa ' + $env:COMPUTERNAME + '</title><style>body{font-family:Segoe UI,Segoe UI Emoji,sans-serif;background:#1e1e1e;color:#d4d4d4;padding:24px;margin:0}h1{color:#4fc1ff;font-size:20px;margin:0 0 8px}.meta{color:#9cdcfe;font-size:12px;margin-bottom:14px}pre{background:#141414;padding:16px;border-radius:8px;white-space:pre-wrap;word-break:break-word;font-family:Consolas,monospace;font-size:12px;line-height:1.45;border:1px solid #333}</style></head><body><h1>Laporan Diagnosa Komputer</h1><div class="meta">' + $meta + '</div><pre>' + $esc + '</pre></body></html>'
                    [System.IO.File]::WriteAllText($path, $html, (New-Object System.Text.UTF8Encoding $true))
                    Add-Output "`nLaporan tersimpan: $path`n" '#6A9955'
                    Start-Process $path
                }
                Note = 'Laporan otomatis terbuka di browser - siap dilampirkan ke tiket/arsip.'
            }
            @{
                Name = '📅 Pasang Maintenance Mingguan'
                Desc = 'Jadwalkan AIO bersih-bersih otomatis tiap Minggu 09:00'
                Type = 'fix'
                Build = {
                    param($v)
                    @('powershell -NoProfile -Command "try { $a = New-ScheduledTaskAction -Execute ''powershell.exe'' -Argument (''-NoProfile -ExecutionPolicy Bypass -File \"TKSCRIPTPATH\" -Run \"AIO\"''); $t = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 09:00; Register-ScheduledTask -TaskName ''ITToolkit-Maintenance'' -Action $a -Trigger $t -Force | Out-Null; Write-Host ''MAINTENANCE TERPASANG: tiap Minggu 09:00 PC menjalankan AIO otomatis (tanpa recycle bin).'' } catch { Write-Host (''GAGAL: '' + $_.Exception.Message) }"'.Replace('TKSCRIPTPATH', $script:ScriptPath))
                }
                Note = 'Untuk dipasang di PC client. Copot kapan saja lewat tombol di bawah ini.'
            }
            @{
                Name = '📅 Hapus Maintenance Terjadwal'
                Desc = 'Copot task mingguan ITToolkit-Maintenance'
                Type = 'fix'
                Cmds = @(
                    'powershell -NoProfile -Command "try { Unregister-ScheduledTask -TaskName ''ITToolkit-Maintenance'' -Confirm:$false -ErrorAction Stop; Write-Host ''Maintenance mingguan dihapus.'' } catch { Write-Host (''GAGAL / TIDAK ADA: '' + $_.Exception.Message) }"'
                )
            }
        )
    }
    @{
        Key   = 'network'
        Title = '🌐 Jaringan'
        Items = @(
            @{
                Name = '📶 Info IP & Adapter Lengkap'
                Desc = 'ipconfig /all + daftar MAC address'
                Type = 'check'
                Cmds = @(
                    'ipconfig /all'
                    'getmac /v /fo list'
                )
            }
            @{
                Name = '🏠 Cek Koneksi ke Gateway/Router'
                Desc = 'Deteksi otomatis gateway lalu ping - cek router/modem'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "$gw = (Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Sort-Object RouteMetric | Select-Object -First 1).NextHop; if (-not $gw) { Write-Host ''Gateway tidak ditemukan - cek adapter dulu'' } else { Write-Host (''Gateway : '' + $gw); ping $gw -n 4 }"'
                )
            }
            @{
                Name = '📡 Tes Ping Internet'
                Desc = 'Ping Google DNS & Cloudflare - cek stabilitas internet'
                Type = 'check'
                Cmds = @(
                    'ping 8.8.8.8 -n 10'
                    'ping 1.1.1.1 -n 4'
                )
            }
            @{
                Name = '🗺️ Traceroute ke Google ⏱️'
                Desc = 'Lacak jalur koneksi - cari titik putus internet'
                Type = 'check'
                Cmds = @(
                    'tracert -d 8.8.8.8'
                )
            }
            @{
                Name = '🔍 Tes DNS (nslookup)'
                Desc = 'Cek resolusi nama domain - diagnosa DNS bermasalah'
                Type = 'check'
                Cmds = @(
                    'nslookup google.com'
                    'nslookup detik.com'
                )
            }
            @{
                Name = '🧭 Tabel Routing & ARP'
                Desc = 'route print + arp -a - diagnosa routing LAN'
                Type = 'check'
                Cmds = @(
                    'route print'
                    'arp -a'
                )
            }
            @{
                Name = '🗂️ Profil WiFi Tersimpan'
                Desc = 'Daftar WiFi yang pernah tersambung + info koneksi aktif'
                Type = 'check'
                Cmds = @(
                    'netsh wlan show profiles'
                    'netsh wlan show interfaces'
                )
            }
            @{
                Name = '🔑 Tampilkan Semua Password WiFi'
                Desc = 'Ekstrak password semua WiFi yang tersimpan di PC'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "netsh wlan show profiles | Select-String -Pattern ''All User Profile|Profil Semua Pengguna'' | ForEach-Object { $n = ($_.ToString().Split('':'')[-1]).Trim(); $k = netsh wlan show profile name=\"$n\" key=clear | Select-String -Pattern ''Key Content|Isi Kunci''; if ($k) { Write-Host (''WiFi : '' + $n + ''  -->  Password : '' + ($k.ToString().Split('':'')[-1].Trim())) } else { Write-Host (''WiFi : '' + $n + ''  -->  (terbuka / tanpa password)'') } }"'
                )
            }
            @{
                Name = '🔄 Perbarui IP (Release + Renew)'
                Desc = 'Ambil IP baru dari DHCP - fix konflik IP / tidak dapat IP'
                Type = 'fix'
                Cmds = @(
                    'ipconfig /release'
                    'ipconfig /renew'
                )
                Note = 'Koneksi internet putus sesaat saat perpanjangan IP.'
            }
            @{
                Name = '🧽 Flush DNS Cache'
                Desc = 'Hapus cache DNS - fix situs tidak bisa dibuka'
                Type = 'fix'
                Cmds = @(
                    'ipconfig /flushdns'
                )
            }
            @{
                Name = '🔌 Reset Winsock (Fix Internet)'
                Desc = 'Reset katalog jaringan Windows - fix internet mati total'
                Type = 'fix'
                Cmds = @(
                    'netsh winsock reset'
                )
                Note = 'WAJIB RESTART PC agar berlaku.'
            }
            @{
                Name = '🧱 Reset TCP/IP & Interface'
                Desc = 'Reset stack TCP/IP - fix jaringan rusak parah'
                Type = 'fix'
                Cmds = @(
                    'netsh int ip reset'
                    'netsh int tcp reset'
                )
                Note = 'WAJIB RESTART PC. IP statik/dns manual akan kembali ke default.'
            }
            @{
                Name = '⚙️ Set DNS Google (8.8.8.8)'
                Desc = 'Semua adapter aktif memakai DNS 8.8.8.8 / 8.8.4.4'
                Type = 'fix'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-NetAdapter | Where-Object Status -eq Up | Set-DnsClientServerAddress -ServerAddresses 8.8.8.8,8.8.4.4"'
                )
                Note = 'Cek dengan tombol Tes DNS setelahnya.'
            }
            @{
                Name = '☁️ Set DNS Cloudflare (1.1.1.1)'
                Desc = 'Semua adapter aktif memakai DNS 1.1.1.1 / 1.0.0.1'
                Type = 'fix'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-NetAdapter | Where-Object Status -eq Up | Set-DnsClientServerAddress -ServerAddresses 1.1.1.1,1.0.0.1"'
                )
            }
            @{
                Name = '↩️ DNS Kembali Otomatis (DHCP)'
                Desc = 'Hapus DNS manual, kembali ke setting otomatis ISP/router'
                Type = 'fix'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-NetAdapter | Set-DnsClientServerAddress -ResetServerAddresses"'
                )
            }
            @{
                Name = '🚫 Reset Proxy (Internet Terblokir)'
                Desc = 'Matikan proxy sistem - fix internet mati setelah malware/VPN'
                Type = 'fix'
                Cmds = @(
                    'netsh winhttp reset proxy'
                    'reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f'
                    'reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /f'
                    'reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoConfigURL /f'
                )
                Note = 'Jika baris reg delete error "unable to find" = bagus, memang tidak ada. Tutup & buka browser lagi.'
            }
            @{
                Name = '♻️ Restart Semua Adapter Jaringan'
                Desc = 'Disable-enable WiFi/LAN - fix WiFi ilang / limited'
                Type = 'fix'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-NetAdapter | Where-Object Status -ne Disabled | Restart-NetAdapter -Confirm:$false"'
                )
                Note = 'Koneksi putus sesaat lalu tersambung kembali.'
            }
            @{
                Name = '🛠️ Restart Layanan Jaringan'
                Desc = 'Restart service DHCP & Network Location Awareness'
                Type = 'fix'
                Cmds = @(
                    'powershell -NoProfile -Command "Restart-Service Dhcp -Force -ErrorAction SilentlyContinue; Restart-Service NlaSvc -Force -ErrorAction SilentlyContinue; Write-Host ''Layanan jaringan direstart - cek internet kembali.''"'
                )
            }
            @{
                Name = '🔗 Koneksi Aktif & Port Terbuka'
                Desc = 'netstat -ano: deteksi program/koneksi mencurigakan'
                Type = 'check'
                Cmds = @(
                    'netstat -ano'
                )
                Note = 'Cocokkan angka PID dengan Task Manager (tab Details) untuk tahu programnya.'
            }
            @{
                Name = '🔌 Tes Port Host (Printer/Server)'
                Desc = 'Cek port TCP terbuka, contoh printer: port 9100'
                Type = 'check'
                Input = @(
                    @{ Prompt = 'Host/IP tujuan:'; Default = '192.168.0.1' }
                    @{ Prompt = 'Port TCP:'; Default = '80' }
                )
                Build = {
                    param($v)
                    @('powershell -NoProfile -Command "Test-NetConnection -ComputerName ' + $v[0] + ' -Port ' + $v[1] + ' | Format-List ComputerName,RemotePort,TcpTestSucceeded,PingSucceeded"')
                }
                Note = 'TcpTestSucceeded : True = port terbuka dan bisa dihubungi.'
            }
            @{
                Name = '🎯 Diagnosa Host Tertentu'
                Desc = 'Ping + nslookup + tracert ke host/IP yang Anda tentukan'
                Type = 'check'
                Input = @(
                    @{ Prompt = 'Host / domain / IP tujuan:'; Default = 'google.com' }
                )
                Build = {
                    param($v)
                    @(
                        ('ping ' + $v[0] + ' -n 4'),
                        ('nslookup ' + $v[0]),
                        ('tracert -d -h 15 ' + $v[0])
                    )
                }
            }
            @{
                Name = '⚙️ Set IP Statik (Input Manual)'
                Desc = 'Pasang IP fix untuk adapter tertentu - printer/camera/server'
                Type = 'danger'
                Input = @(
                    @{ Prompt = 'Nama adapter (lihat Info IP):'; Default = 'Wi-Fi' }
                    @{ Prompt = 'IP statik:'; Default = '192.168.1.50' }
                    @{ Prompt = 'Gateway:'; Default = '192.168.1.1' }
                    @{ Prompt = 'Subnet mask:'; Default = '255.255.255.0' }
                    @{ Prompt = 'DNS utama:'; Default = '8.8.8.8' }
                    @{ Prompt = 'DNS cadangan:'; Default = '8.8.4.4' }
                )
                Build = {
                    param($v)
                    @(
                        ('netsh interface ip set address name="' + $v[0] + '" source=static addr=' + $v[1] + ' mask=' + $v[3] + ' gateway=' + $v[2]),
                        ('netsh interface ip set dns name="' + $v[0] + '" static ' + $v[4] + ' primary'),
                        ('netsh interface ip add dns name="' + $v[0] + '" ' + $v[5] + ' index=2'),
                        'ipconfig /all'
                    )
                }
                Note = 'Koneksi akan memakai IP baru. Cek hasil ipconfig di output untuk verifikasi.'
            }
            @{
                Name = '⚙️ Set IP Otomatis (DHCP)'
                Desc = 'Kembalikan adapter ke IP otomatis dari router'
                Type = 'danger'
                Input = @(
                    @{ Prompt = 'Nama adapter (lihat Info IP):'; Default = 'Wi-Fi' }
                )
                Build = {
                    param($v)
                    @(
                        ('netsh interface ip set address name="' + $v[0] + '" source=dhcp'),
                        ('netsh interface ip set dns name="' + $v[0] + '" source=dhcp'),
                        'ipconfig /renew'
                    )
                }
            }
            @{
                Name = '👁️ Lihat Setting Proxy Aktif'
                Desc = 'Cek proxy sistem & browser sebelum di-reset'
                Type = 'check'
                Cmds = @(
                    'netsh winhttp show proxy'
                    'reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable'
                    'reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer'
                )
                Note = 'Error "unable to find" = setting tidak ada (normal). ProxyEnable 0x1 = proxy menyala.'
            }
            @{
                Name = '📂 Shared Folders & Drive Map'
                Desc = 'Folder sharing & drive jaringan yang terpasang'
                Type = 'check'
                Cmds = @(
                    'net share'
                    'net use'
                )
            }
            @{
                Name = '💣 Reset Total Jaringan (Nuklir)'
                Desc = 'Semua reset jaringan sekaligus: DNS+IP+Winsock+TCP+Adapter'
                Type = 'danger'
                Cmds = @(
                    'ipconfig /flushdns'
                    'ipconfig /release'
                    'ipconfig /renew'
                    'netsh winsock reset'
                    'netsh int ip reset'
                    'netsh int tcp reset'
                    'powershell -NoProfile -Command "Get-NetAdapter | Where-Object Status -ne Disabled | Restart-NetAdapter -Confirm:$false"'
                )
                Note = 'WAJIB RESTART PC setelah ini. IP statik/DNS manual kembali ke default - catat dulu sebelum lanjut.'
            }
            @{
                Name = '🚀 Speed Test Internet'
                Desc = 'Ukur throughput download nyata via Cloudflare'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "$t = [Diagnostics.Stopwatch]::StartNew(); $tmp = Join-Path $env:TEMP (''spd-'' + [guid]::NewGuid().ToString(''N'')); try { Invoke-WebRequest -Uri ''https://speed.cloudflare.com/__down?bytes=25000000'' -OutFile $tmp -UseBasicParsing -ErrorAction Stop; $t.Stop(); $mbps = [math]::Round(25 * 8 / $t.Elapsed.TotalSeconds, 1); Write-Host (''Kecepatan download : '' + $mbps + '' Mbps (25 MB dalam '' + [math]::Round($t.Elapsed.TotalSeconds,1) + '' detik)'') } catch { Write-Host (''GAGAL: '' + $_.Exception.Message) } finally { Remove-Item $tmp -ErrorAction SilentlyContinue }"'
                )
                Note = 'Butuh internet. Hasil bisa berbeda-beda tergantung server/waktu - jalankan 2-3x untuk gambaran.'
            }
            @{
                Name = '🧽 Lihat Isi Cache DNS'
                Desc = 'ipconfig /displaydns - domain yang baru diakses'
                Type = 'check'
                Cmds = @(
                    'ipconfig /displaydns'
                )
                Note = 'Bisa sangat panjang. Berguna cek domain mencurigakan yang baru diakses.'
            }
        )
    }
    @{
        Key = 'remote'; OS = 'Windows'; Title = '📡 Remote & LAN'
        Items = @(
            @{
                Name = '🖥️ Diagnosa PC Remote (WinRM)'
                Desc = 'Cek OS/disk/Defender/update PC lain dari jendela ini'
                Type = 'check'
                Input = @(
                    @{ Prompt = 'Nama / IP PC tujuan:'; Default = 'localhost' }
                )
                Build = {
                    param($v)
                    @('powershell -NoProfile -Command "try { Invoke-Command -ComputerName ' + $v[0] + ' -ScriptBlock { Write-Host ===OS===; $os = Get-CimInstance Win32_OperatingSystem; Write-Host (''OS   : '' + $os.Caption + '' (build '' + $os.BuildNumber + '')''); Write-Host (''Boot : '' + $os.LastBootUpTime); $cs = Get-CimInstance Win32_ComputerSystem; Write-Host (''Merk : '' + $cs.Manufacturer + '' '' + $cs.Model); Write-Host ===DISK===; Get-Volume | Where-Object DriveLetter | Format-Table DriveLetter,@{n=''FreeGB'';e={[math]::Round($_.SizeRemaining/1GB,1)}},@{n=''TotalGB'';e={[math]::Round($_.Size/1GB,1)}} -AutoSize; Write-Host ===DEFENDER===; try { Get-MpComputerStatus | Format-List AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureLastUpdated } catch {}; Write-Host ===UPDATE===; Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 5 | Format-Table HotFixID,InstalledOn -AutoSize; Write-Host ===ERROR===; Get-WinEvent -FilterHashtable @{LogName=''System'';Level=2} -MaxEvents 5 -ErrorAction SilentlyContinue | Format-Table TimeCreated,ProviderName -AutoSize; Write-Host ===SELESAI=== } -ErrorAction Stop } catch { Write-Host (''GAGAL: '' + $_.Exception.Message); Write-Host ''Pastikan: WinRM aktif di PC tujuan (jalankan winrm quickconfig sebagai admin di sana) + Anda admin di PC tujuan.''"')
                }
            }
            @{
                Name = '⚙️ Aktifkan WinRM di PC Ini'
                Desc = 'winrm quickconfig - agar PC ini bisa didiagnosa remote'
                Type = 'fix'
                Cmds = @(
                    'winrm quickconfig'
                )
                Note = 'Membuka port WinRM (5985) & menyalakan firewall rule terkait. Matikan dengan: winrm delete winrm/config/listener?Transport=HTTP'
            }
            @{
                Name = '📡 Scan Perangkat LAN ⏱️'
                Desc = 'Ping sweep subnet + tabel ARP (IP-MAC perangkat)'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "$g = (Get-NetRoute -DestinationPrefix 0.0.0.0/0 | Sort-Object RouteMetric | Select-Object -First 1).NextHop; if (-not $g) { Write-Host ''Tidak ada gateway aktif''; exit }; $base = (($g -split ''\.'')[0..2] -join ''.''); Write-Host (''Scan subnet '' + $base + ''.0/24 - mohon tunggu sekitar 30-60 detik...''); $p = New-Object System.Net.NetworkInformation.Ping; $n = 0; 1..254 | ForEach-Object { $ip = $base + ''.'' + $_; try { if ($p.Send($ip, 100).Status -eq ''Success'') { $n++; Write-Host (''AKTIF : '' + $ip) } } catch {} }; Write-Host (''Selesai - '' + $n + '' perangkat merespons. IP-MAC ada di hasil arp -a berikut.'')"'
                    'arp -a'
                )
                Note = 'MAC address bisa dicek vendornya lewat situs lookup MAC untuk identifikasi perangkat.'
            }
        )
    }
    @{
        Key   = 'system'
        Title = '🖥️ Sistem'
        Items = @(
            @{
                Name = 'ℹ️ Informasi Sistem Lengkap ⏱️'
                Desc = 'systeminfo: OS, RAM, network, uptime, hotfix'
                Type = 'check'
                Cmds = @(
                    'systeminfo'
                )
            }
            @{
                Name = '🧩 Informasi Hardware'
                Desc = 'Merk PC, CPU, GPU, motherboard, BIOS'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-CimInstance Win32_ComputerSystem | Format-List Manufacturer,Model,TotalPhysicalMemory,NumberOfProcessors"'
                    'powershell -NoProfile -Command "Get-CimInstance Win32_Processor | Format-List Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed,LoadPercentage"'
                    'powershell -NoProfile -Command "Get-CimInstance Win32_VideoController | Format-List Name,DriverVersion,Status"'
                    'powershell -NoProfile -Command "Get-CimInstance Win32_BaseBoard | Format-List Manufacturer,Product,Version"'
                    'powershell -NoProfile -Command "Get-CimInstance Win32_BIOS | Format-List Manufacturer,SMBIOSBIOSVersion,SerialNumber"'
                )
            }
            @{
                Name = '🔋 Status Baterai Laptop'
                Desc = 'Persentase & status baterai (kalau ada)'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-CimInstance Win32_Battery | Format-List Name,EstimatedChargeRemaining,BatteryStatus,Status"'
                )
            }
            @{
                Name = '⏱️ Uptime & RAM'
                Desc = 'Lama PC nyala sejak boot terakhir + pemakaian RAM'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "$os = Get-CimInstance Win32_OperatingSystem; Write-Host (''Boot terakhir : '' + $os.LastBootUpTime); Write-Host (''Uptime        : '' + ((Get-Date) - $os.LastBootUpTime).ToString())"'
                    'powershell -NoProfile -Command "$os = Get-CimInstance Win32_OperatingSystem; Write-Host (''RAM terpasang : '' + [math]::Round($os.TotalVisibleMemorySize/1MB,1) + '' GB''); Write-Host (''RAM bebas     : '' + [math]::Round($os.FreePhysicalMemory/1MB,1) + '' GB'')"'
                )
            }
            @{
                Name = '📜 15 Log Error Sistem Terakhir'
                Desc = 'Event log error - cari penyebab crash/blue screen'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-WinEvent -FilterHashtable @{LogName=''System'';Level=2} -MaxEvents 15 -ErrorAction SilentlyContinue | Format-List TimeCreated,ProviderName,Id,Message"'
                )
            }
            @{
                Name = '🚀 Daftar Aplikasi Startup'
                Desc = 'Program yang jalan otomatis saat PC dinyalakan'
                Type = 'check'
                Cmds = @(
                    'reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"'
                    'reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"'
                    'powershell -NoProfile -Command "Get-CimInstance Win32_StartupCommand | Format-Table Name,Command,Location,User -AutoSize -Wrap"'
                )
            }
            @{
                Name = '📦 Daftar Program Terinstall'
                Desc = 'Semua aplikasi + versi (untuk audit/laporan)'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-ItemProperty ''HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'',''HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'',''HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'' -ErrorAction SilentlyContinue | Where-Object DisplayName | Sort-Object DisplayName | Format-Table DisplayName,DisplayVersion,Publisher,InstallDate -AutoSize"'
                )
            }
            @{
                Name = '🔐 Status Lisensi Windows'
                Desc = 'Cek aktivasi & masa aktif lisensi Windows'
                Type = 'check'
                Cmds = @(
                    'cscript //nologo "%SystemRoot%\System32\slmgr.vbs" /dli'
                    'cscript //nologo "%SystemRoot%\System32\slmgr.vbs" /xpr'
                )
            }
            @{
                Name = '🛡️ Status UAC & SmartScreen'
                Desc = 'Cek pengaturan keamanan User Account Control'
                Type = 'check'
                Cmds = @(
                    'reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA'
                    'reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin'
                    'reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v SmartScreenEnabled'
                )
            }
            @{
                Name = '🩹 SFC /scannow ⏱️'
                Desc = 'Scan & perbaiki file sistem Windows yang rusak'
                Type = 'fix'
                Cmds = @(
                    'sfc /scannow'
                )
                Note = '10-30 menit. Jangan tutup sampai status bar tulis Selesai.'
            }
            @{
                Name = '🏗️ DISM RestoreHealth ⏱️'
                Desc = 'Perbaiki image Windows (jalan dulu, lalu SFC)'
                Type = 'fix'
                Cmds = @(
                    'dism /online /cleanup-image /checkhealth'
                    'dism /online /cleanup-image /scanhealth'
                    'dism /online /cleanup-image /restorehealth'
                )
                Note = 'Butuh internet. 15-60 menit. Setelah ini jalankan SFC /scannow.'
            }
            @{
                Name = '🔁 Restart Explorer'
                Desc = 'Fix taskbar/desktop/dialog Windows macet atau hilang'
                Type = 'fix'
                Cmds = @(
                    'taskkill /f /im explorer.exe'
                    'start explorer.exe'
                )
                Note = 'Desktop/taskbar berkedip sesaat - itu normal.'
            }
            @{
                Name = '🧯 Kosongkan Log Event Viewer'
                Desc = 'Hapus semua log sistem & aplikasi'
                Type = 'danger'
                Cmds = @(
                    'powershell -NoProfile -Command "wevtutil el | ForEach-Object { wevtutil cl $_ 2>$null }; Write-Host ''Semua log event dibersihkan.'' "'
                )
                Note = 'Riwayat log error hilang permanen - pastikan sudah dibaca/simpan dulu.'
            }
            @{
                Name = '📅 Jadwalkan CHKDSK Saat Restart'
                Desc = 'Perbaiki bad sector & error file system drive C'
                Type = 'danger'
                Cmds = @(
                    'powershell -NoProfile -Command "Repair-Volume -DriveLetter C -OfflineScanAndFix"'
                )
                Note = 'Akan berjalan saat restart berikutnya (bisa berjam-jam). Bisa dibatalkan dengan tombol Batalkan CHKDSK Terjadwal.'
            }
            @{
                Name = '🔄 Restart Komputer'
                Desc = 'Restart 30 detik setelah klik (bisa dibatalkan)'
                Type = 'danger'
                Cmds = @(
                    'shutdown /r /t 30 /c "Restart oleh IT Support Toolkit"'
                )
            }
            @{
                Name = '⏻ Matikan Komputer'
                Desc = 'Shutdown 30 detik setelah klik (bisa dibatalkan)'
                Type = 'danger'
                Cmds = @(
                    'shutdown /s /t 30 /c "Shutdown oleh IT Support Toolkit"'
                )
            }
            @{
                Name = '🛑 Batalkan Shutdown Terjadwal'
                Desc = 'shutdown /a — batal jika salah klik restart/mati'
                Type = 'fix'
                Cmds = @(
                    'shutdown /a'
                )
                Note = 'Hanya bekerja SEBELUM hitungan 30 detik shutdown selesai.'
            }
            @{
                Name = '⛔ Batalkan CHKDSK Terjadwal'
                Desc = 'chkntfs /x C: — batal auto-scan disk saat restart'
                Type = 'fix'
                Cmds = @(
                    'chkntfs /x C:'
                )
                Note = 'Dijalankan sebelum restart berikutnya supaya CHKDSK tidak otomatis jalan.'
            }
            @{
                Name = '🛡️ Aktifkan System Restore (C:)'
                Desc = 'Wajib dulu sebelum bisa membuat restore point'
                Type = 'fix'
                Cmds = @(
                    'powershell -NoProfile -Command "Enable-ComputerRestore -Drive ''C:\'' -ErrorAction SilentlyContinue; vssadmin resize shadowstorage /for=C: /on=C: /maxsize=10%; Write-Host ''System Restore diaktifkan untuk C: (maks 10% disk).''"'
                )
            }
            @{
                Name = '💾 Buat Restore Point Sekarang'
                Desc = 'Titik rollback manual sebelum perbaikan berisiko'
                Type = 'fix'
                Cmds = @(
                    'powershell -NoProfile -Command "reg add ''HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'' /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f | Out-Null; try { Checkpoint-Computer -Description ''IT-Toolkit Manual'' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop; Write-Host ''Restore point berhasil dibuat.'' } catch { Write-Host (''GAGAL: '' + $_.Exception.Message) }"'
                )
                Note = 'Proses 30-90 detik. Jika gagal, jalankan dulu tombol Aktifkan System Restore (C:).'
            }
            @{
                Name = '🧩 Info Keping RAM (Slot/Speed)'
                Desc = 'Keping RAM per slot: kapasitas, speed, part number'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-CimInstance Win32_PhysicalMemory | Format-Table BankLabel,@{n=''GB'';e={[math]::Round($_.Capacity/1GB,1)}},Speed,Manufacturer,PartNumber -AutoSize"'
                )
                Note = 'Berguna sebelum upgrade RAM - pastikan speed & tipe sama dengan keping lama.'
            }
            @{
                Name = '🔑 Product Key Windows (OEM BIOS)'
                Desc = 'Key lisensi asli tertanam di BIOS/UEFI'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "$k = (Get-CimInstance SoftwareLicensingService).OA3xOriginalProductKey; if ($k) { Write-Host (''Product Key (OEM BIOS): '' + $k) } else { Write-Host ''Tidak ada key OEM di BIOS/UEFI (kemungkinan lisensi digital / retail).'' }"'
                )
                Note = 'Catat key ini SEBELUM reinstall Windows - aktivasi otomatis dikenali saat instalasi ulang.'
            }
            @{
                Name = '🆘 Advanced Startup / WinRE'
                Desc = 'Restart ke menu Recovery: Safe Mode, repair, UEFI'
                Type = 'danger'
                Cmds = @(
                    'shutdown /r /o /t 0'
                )
                Note = 'PC langsung restart ke menu Advanced Startup (Safe Mode, System Restore, Startup Repair). Simpan pekerjaan dulu!'
            }
        )
    }
    @{
        Key   = 'disk'
        Title = '💾 Disk'
        Items = @(
            @{
                Name = '💾 Kapasitas Semua Drive'
                Desc = 'Sisa ruang, total, & health tiap partisi'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-Volume | Where-Object DriveLetter | Format-Table DriveLetter,FileSystemLabel,FileSystem,@{n=''FreeGB'';e={[math]::Round($_.SizeRemaining/1GB,1)}},@{n=''TotalGB'';e={[math]::Round($_.Size/1GB,1)}},HealthStatus -AutoSize"'
                )
            }
            @{
                Name = '🩺 Kesehatan Harddisk/SSD (SMART)'
                Desc = 'Status health, suhu & wear disk - deteksi disk mau rusak'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-PhysicalDisk | Format-Table FriendlyName,HealthStatus,OperationalStatus,MediaType,@{n=''SizeGB'';e={[math]::Round($_.Size/1GB)}} -AutoSize"'
                    'powershell -NoProfile -Command "Get-PhysicalDisk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue | Format-Table DeviceId,Temperature,Wear,ReadErrorsUncorrected,WriteErrorsUncorrected -AutoSize"'
                )
            }
            @{
                Name = '🧪 Scan Error Drive C (Aman)'
                Desc = 'Cek error file system tanpa mengubah apa pun'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "try { Repair-Volume -DriveLetter C -Scan -ErrorAction Stop } catch { Write-Host (''GAGAL: '' + $_.Exception.Message); Write-Host ''Scan drive butuh hak Administrator (GUI toolkit selalu admin).'' }"'
                )
            }
            @{
                Name = '🔧 Perbaiki Error Drive C (SpotFix)'
                Desc = 'Perbaikan cepat error file system yang terdeteksi'
                Type = 'fix'
                Cmds = @(
                    'powershell -NoProfile -Command "try { Repair-Volume -DriveLetter C -SpotFix -ErrorAction Stop } catch { Write-Host (''GAGAL: '' + $_.Exception.Message); Write-Host ''Perbaikan drive butuh hak Administrator.'' }"'
                )
                Note = 'Drive C dikunci sesaat saat perbaikan.'
            }
            @{
                Name = '⚡ Optimasi/TRIM Drive C ⏱️'
                Desc = 'Defrag HDD / TRIM SSD - tingkatkan performa disk'
                Type = 'fix'
                Cmds = @(
                    'defrag C: /O'
                )
                Note = '5-30 menit tergantung disk.'
            }
            @{
                Name = '🧰 Pembersihan Komponen Windows ⏱️'
                Desc = 'Bersihkan WinSxS - kecilkan ukuran folder Windows'
                Type = 'fix'
                Cmds = @(
                    'dism /online /cleanup-image /startcomponentcleanup'
                )
                Note = '20-60 menit. Jangan matikan PC saat proses jalan.'
            }
            @{
                Name = '🗑️ Buka Disk Cleanup (GUI)'
                Desc = 'Panel bersih-bersih bawaan Windows'
                Type = 'open'
                Target = 'cleanmgr'
            }
            @{
                Name = '📊 Analisa Ruang Disk C: ⏱️'
                Desc = 'Folder terbesar + file >500MB (2-10 menit, satu kali scan)'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "& { $tops = @{}; $big = New-Object System.Collections.Generic.List[string]; function Walk($d, $topName) { Get-ChildItem -LiteralPath $d -Force -ErrorAction SilentlyContinue | ForEach-Object { if ($_.PSIsContainer) { if (-not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)) { Walk $_.FullName $topName } } else { if ($tops.ContainsKey($topName)) { $tops[$topName] += $_.Length } else { $tops[$topName] = $_.Length }; if ($_.Length -gt 500MB) { $big.Add(([math]::Round($_.Length/1GB,2)).ToString() + '' GB|'' + $_.FullName) } } } }; Get-ChildItem ''C:\'' -Directory -Force -ErrorAction SilentlyContinue | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } | ForEach-Object { Walk $_.FullName $_.Name }; Get-ChildItem ''C:\'' -File -Force -ErrorAction SilentlyContinue | ForEach-Object { if ($tops.ContainsKey(''(root)'')) { $tops[''(root)''] += $_.Length } else { $tops[''(root)''] = $_.Length } }; Write-Host ''=== FOLDER TERBESAR DI C:\ (rekap per folder top-level) ===''; $tops.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { Write-Host (([math]::Round($_.Value/1GB,2)).ToString() + '' GB  '' + $_.Key) }; Write-Host ''''.PadRight(60); Write-Host ''=== FILE TERBESAR >500MB (25 teratas) ===''; $big | ForEach-Object { $q = $_.Split(''|''); [PSCustomObject]@{ GB = [double]$q[0]; Path = $q[1] } } | Sort-Object GB -Descending | Select-Object -First 25 | ForEach-Object { Write-Host ($_.GB.ToString() + '' GB  '' + $_.Path) } }"'
                )
                Note = 'Scan seluruh C: satu kali (2-10 menit tergantung isi disk). Junction/symlink tidak diikuti agar ukuran akurat.'
            }
            @{
                Name = '📂 Buka Manajemen Disk'
                Desc = 'Partisi, format, ubah huruf drive'
                Type = 'open'
                Target = 'diskmgmt.msc'
            }
        )
    }
    @{
        Key   = 'update'
        Title = '🔄 Update'
        Items = @(
            @{
                Name = '🔢 Versi & Build Windows'
                Desc = 'Cek versi Windows yang terpasang saat ini'
                Type = 'check'
                Cmds = @(
                    'reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName'
                    'reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v DisplayVersion'
                    'reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber'
                    'reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v UBR'
                )
            }
            @{
                Name = '📦 15 Hotfix/Update Terakhir'
                Desc = 'Riwayat patch Windows yang sudah terpasang'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 15 HotFixID,Description,InstalledOn | Format-Table -AutoSize"'
                )
            }
            @{
                Name = '🌐 Buka Windows Update (Settings)'
                Desc = 'Panel update bawaan Windows'
                Type = 'open'
                Target = 'ms-settings:windowsupdate'
            }
            @{
                Name = '🔄 Reset Cache Windows Update'
                Desc = 'Fix update gagal/error 0x80070002, stuck, dll'
                Type = 'fix'
                Cmds = @(
                    'net stop wuauserv'
                    'net stop cryptSvc'
                    'net stop bits'
                    'net stop msiserver'
                    'if exist "%SystemRoot%\SoftwareDistribution.old" rd /s /q "%SystemRoot%\SoftwareDistribution.old"'
                    'if exist "%SystemRoot%\System32\catroot2.old" rd /s /q "%SystemRoot%\System32\catroot2.old"'
                    'ren "%SystemRoot%\SoftwareDistribution" SoftwareDistribution.old'
                    'ren "%SystemRoot%\System32\catroot2" catroot2.old'
                    'net start msiserver'
                    'net start bits'
                    'net start cryptSvc'
                    'net start wuauserv'
                )
                Note = 'Setelah ini buka Windows Update dan cek update lagi (download dimulai dari nol).'
            }
            @{
                Name = '🔃 Restart Layanan Update'
                Desc = 'Restart wuauserv & BITS - fix update macet'
                Type = 'fix'
                Cmds = @(
                    'net stop wuauserv'
                    'net stop bits'
                    'net start bits'
                    'net start wuauserv'
                )
            }
            @{
                Name = '🩺 Buka Troubleshooter'
                Desc = 'Pemecah masalah bawaan Windows (update, internet, dll)'
                Type = 'open'
                Target = 'ms-settings:troubleshoot'
            }
        )
    }
    @{
        Key   = 'printer'
        Title = '🖨️ Printer'
        Items = @(
            @{
                Name = '🖨️ Daftar Printer & Status'
                Desc = 'Cek printer terpasang, driver & port'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-Printer | Format-Table Name,DriverName,PortName,PrinterStatus,Shared -AutoSize"'
                )
            }
            @{
                Name = '📄 Antrian Print (Semua Printer)'
                Desc = 'Dokumen yang sedang/belum tercetak'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "$j = Get-Printer | ForEach-Object { Get-PrintJob -PrinterName $_.Name -ErrorAction SilentlyContinue }; if ($j) { $j | Format-Table PrinterName,Id,DocumentName,UserName,JobStatus -AutoSize } else { Write-Host ''Antrian kosong - tidak ada dokumen nyangkut.'' }"'
                )
            }
            @{
                Name = '🛠️ Restart Print Spooler'
                Desc = 'Fix printer offline / tidak merespons'
                Type = 'fix'
                Cmds = @(
                    'net stop spooler'
                    'net start spooler'
                )
            }
            @{
                Name = '🧹 Kosongkan Antrian Print'
                Desc = 'Hapus dokumen nyangkut yang bikin printer macet'
                Type = 'danger'
                Cmds = @(
                    'net stop spooler'
                    'del /f /q "%SystemRoot%\System32\spool\PRINTERS\*.*"'
                    'net start spooler'
                )
                Note = 'Semua dokumen dalam antrian dibatalkan permanen.'
            }
            @{
                Name = '⚙️ Buka Printer & Scanner'
                Desc = 'Pengaturan printer di Windows Settings'
                Type = 'open'
                Target = 'ms-settings:printers'
            }
        )
    }
    @{
        Key   = 'security'
        Title = '🛡️ Keamanan'
        Items = @(
            @{
                Name = '🛡️ Status Windows Defender'
                Desc = 'Antivirus aktif? Real-time protection? Definisi terbaru?'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-MpComputerStatus | Format-List AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,AntispywareEnabled,AntivirusSignatureLastUpdated,QuickScanEndTime"'
                )
            }
            @{
                Name = '🔥 Status Firewall'
                Desc = 'Cek firewall profil Domain/Private/Public'
                Type = 'check'
                Cmds = @(
                    'netsh advfirewall show allprofiles state'
                )
            }
            @{
                Name = '👾 Ancaman Terdeteksi Defender'
                Desc = 'Riwayat virus/malware yang pernah ditemukan'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-MpThreat | Format-List ThreatName,SeverityID,IsActive; Get-MpThreatDetection | Select-Object -First 10 InitialDetectionTime,ProcessName,ActionSuccess | Format-List"'
                )
            }
            @{
                Name = '⬆️ Update Definisi Virus Defender'
                Desc = 'Unduh database virus terbaru'
                Type = 'fix'
                Cmds = @(
                    'powershell -NoProfile -Command "Update-MpSignature"'
                )
                Note = 'Butuh internet.'
            }
            @{
                Name = '🔍 Scan Cepat (Quick Scan)'
                Desc = 'Scan area yang paling sering diserang malware'
                Type = 'fix'
                Cmds = @(
                    'powershell -NoProfile -Command "Start-MpScan -ScanType QuickScan"'
                )
                Note = '5-15 menit.'
            }
            @{
                Name = '🔬 Scan Penuh (Full Scan) ⏱️'
                Desc = 'Scan seluruh disk - menyeluruh'
                Type = 'fix'
                Cmds = @(
                    'powershell -NoProfile -Command "Start-MpScan -ScanType FullScan"'
                )
                Note = 'Bisa 1-3 jam. PC akan terasa berat selama scan.'
            }
            @{
                Name = '☢️ Scan Offline (Boot Scan)'
                Desc = 'Scan sebelum Windows jalan - basmi malware bandel'
                Type = 'danger'
                Cmds = @(
                    'powershell -NoProfile -Command "Start-MpScan -ScanType OfflineScan"'
                )
                Note = 'PC akan RESTART & scan saat boot (bisa 15-30 menit). Simpan pekerjaan dulu!'
            }
            @{
                Name = '🔥 Nyalakan Semua Firewall'
                Desc = 'Aktifkan firewall semua profil jaringan'
                Type = 'fix'
                Cmds = @(
                    'netsh advfirewall set allprofiles state on'
                )
            }
            @{
                Name = '🧬 Aktifkan Real-Time Protection'
                Desc = 'Nyalakan lagi proteksi real-time Defender'
                Type = 'fix'
                Cmds = @(
                    'powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring $false"'
                )
            }
            @{
                Name = '🔐 Buka Windows Security'
                Desc = 'Panel keamanan bawaan Windows'
                Type = 'open'
                Target = 'windowsdefender:'
            }
            @{
                Name = '🔒 Status BitLocker (Semua Drive)'
                Desc = 'Cek enkripsi drive aktif/tidak & persentasenya'
                Type = 'check'
                Cmds = @(
                    'manage-bde -status'
                )
                Note = 'Tersedia di Windows Pro/Enterprise. Fully Decrypted = BitLocker tidak aktif.'
            }
            @{
                Name = '🧪 Cek Syarat Windows 11 (TPM dll)'
                Desc = 'TPM 2.0, SecureBoot, RAM, CPU core, ruang disk'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "try { Write-Host (''SecureBoot : '' + (Confirm-SecureBootUEFI)) } catch { Write-Host ''SecureBoot : tidak bisa dibaca (bukan UEFI / butuh admin)'' }"'
                    'powershell -NoProfile -Command "try { $t = Get-Tpm -ErrorAction Stop; Write-Host (''TPM ada : '' + $t.TpmPresent + '' | Siap : '' + $t.TpmReady) } catch { Write-Host ''TPM : tidak bisa dibaca (butuh admin / tidak ada)'' }"'
                    'powershell -NoProfile -Command "$os = Get-CimInstance Win32_OperatingSystem; Write-Host (''RAM     : '' + [math]::Round($os.TotalVisibleMemorySize/1MB,1) + '' GB (min 4 GB)'')"'
                    'powershell -NoProfile -Command "Get-CimInstance Win32_Processor | ForEach-Object { Write-Host (''CPU     : '' + $_.Name + '' | Core: '' + $_.NumberOfCores + '' (min 2)'') }"'
                    'powershell -NoProfile -Command "Get-Volume -DriveLetter C | ForEach-Object { Write-Host (''Disk C  : '' + [math]::Round($_.Size/1GB,1) + '' GB (min 64 GB)'') }"'
                )
                Note = 'Semua hijau/True + RAM/CPU/disk memenuhi minimum = PC siap upgrade Windows 11.'
            }
            @{
                Name = '🕵️ Audit Exclusion Defender'
                Desc = 'Daftar path/proses yang dikecualikan dari antivirus'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-MpPreference | Format-List ExclusionPath,ExclusionProcess,ExclusionExtension"'
                )
                Note = 'Exclusion mencurigakan (folder temp, random exe) = tanda malware/risiko - hapus via Windows Security.'
            }
            @{
                Name = '💾 Riwayat USB Storage (Forensik)'
                Desc = 'Flashdisk/harddisk yang PERNAH terhubung ke PC ini'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-ItemProperty ''HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\*'' -ErrorAction SilentlyContinue | Format-List FriendlyName"'
                )
                Note = 'Berguna untuk audit kebocoran data / deteksi penyebaran malware via flashdisk.'
            }
            @{
                Name = '💥 Riwayat Crash Aplikasi'
                Desc = 'Program apa yang sering error/crash + penyebabnya'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-WinEvent -FilterHashtable @{LogName=''Application'';ProviderName=''Application Error''} -MaxEvents 15 -ErrorAction SilentlyContinue | Format-List TimeCreated,Message"'
                )
                Note = 'Perhatikan "Faulting module" - patokan utama cari penyebab aplikasi force-close.'
            }
            @{
                Name = '🔌 Riwayat Mati Tak Wajar (Listrik)'
                Desc = 'Deteksi PC mati paksa / listrik mati / blue screen paksa'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-WinEvent -FilterHashtable @{LogName=''System'';Id=6008,41} -MaxEvents 10 -ErrorAction SilentlyContinue | Format-Table TimeCreated,Id,ProviderName -AutoSize"'
                )
                Note = '6008 = shutdown tidak bersih, 41 = mati tanpa shutdown. Sering = cek PSU/listrik/overheat.'
            }
            @{
                Name = '⏰ Scheduled Task Non-Microsoft'
                Desc = 'Tugas terjadwal pihak ketiga (sering dipakai malware)'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-ScheduledTask | Where-Object { $_.TaskPath -notlike ''\Microsoft*'' } | Format-Table TaskPath,TaskName,State -AutoSize"'
                )
                Note = 'Task di folder root dengan nama acak & run EXE dari temp = curiga, selidiki.'
            }
        )
    }
    @{
        Key   = 'cleanup'
        Title = '🧹 Bersih-Bersih'
        Items = @(
            @{
                Name = '🗑️ Hapus File Temp User (%TEMP%)'
                Desc = 'Bersihkan file sisa aplikasi di folder user'
                Type = 'fix'
                Cmds = @(
                    'del /f /s /q "%TEMP%\*"'
                    'for /d %%d in ("%TEMP%\*") do rd /s /q "%%d"'
                )
                Note = 'File yang sedang dipakai aplikasi tidak bisa dihapus - normal.'
            }
            @{
                Name = '🧹 Hapus Temp Windows'
                Desc = 'Bersihkan C:\Windows\Temp'
                Type = 'fix'
                Cmds = @(
                    'del /f /s /q "%SystemRoot%\Temp\*"'
                    'for /d %%d in ("%SystemRoot%\Temp\*") do rd /s /q "%%d"'
                )
            }
            @{
                Name = '🧠 Hapus Prefetch Windows'
                Desc = 'Bersihkan file prefetch (cache peluncuran aplikasi)'
                Type = 'fix'
                Cmds = @(
                    'del /f /s /q "%SystemRoot%\Prefetch\*"'
                )
            }
            @{
                Name = '♻️ Kosongkan Recycle Bin'
                Desc = 'Hapus permanen semua isi tempat sampah'
                Type = 'danger'
                Cmds = @(
                    'powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue; Write-Host ''Recycle Bin dikosongkan.'' "'
                )
                Note = 'Tidak bisa dikembalikan lagi.'
            }
            @{
                Name = '🖼️ Rebuild Icon Cache'
                Desc = 'Fix ikon desktop/taskbar rusak, putih, atau hilang'
                Type = 'fix'
                Cmds = @(
                    'taskkill /f /im explorer.exe'
                    'del /a /q "%LOCALAPPDATA%\IconCache.db"'
                    'del /a /f /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db"'
                    'start explorer.exe'
                )
                Note = 'Desktop berkedip sesaat - normal.'
            }
            @{
                Name = '🧼 Bersihkan Semua (AIO)'
                Desc = 'Temp user + temp Windows + prefetch + recycle bin'
                Type = 'danger'
                Cmds = @(
                    'del /f /s /q "%TEMP%\*"'
                    'for /d %%d in ("%TEMP%\*") do rd /s /q "%%d"'
                    'del /f /s /q "%SystemRoot%\Temp\*"'
                    'for /d %%d in ("%SystemRoot%\Temp\*") do rd /s /q "%%d"'
                    'del /f /s /q "%SystemRoot%\Prefetch\*"'
                    'powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue; Write-Host ''Recycle Bin dikosongkan.'' "'
                )
            }
            @{
                Name = '🗄️ Buka Storage Sense'
                Desc = 'Fitur pembersihan otomatis Windows'
                Type = 'open'
                Target = 'ms-settings:storagesense'
            }
            @{
                Name = '🗑️ Buka Disk Cleanup (GUI)'
                Desc = 'Panel bersih-bersih bawaan Windows'
                Type = 'open'
                Target = 'cleanmgr'
            }
        )
    }
    @{
        Key   = 'extra'
        Title = '⚡ Ekstra'
        Items = @(
            @{
                Name = '🕐 Cek Jam, Zona Waktu & NTP'
                Desc = 'Jam salah bikin HTTPS/sertifikat error'
                Type = 'check'
                Cmds = @(
                    'time /t'
                    'date /t'
                    'tzutil /g'
                    'w32tm /query /status'
                )
            }
            @{
                Name = '🕐 Fix Jam Tidak Sinkron (NTP)'
                Desc = 'Sinkronkan jam PC dengan server waktu internet'
                Type = 'fix'
                Cmds = @(
                    'net start w32time'
                    'w32tm /config /manualpeerlist:"time.windows.com pool.ntp.org" /syncfromflags:manual /update'
                    'w32tm /resync /force'
                    'w32tm /query /status'
                )
                Note = 'Jika zona waktunya salah, ubah lewat Settings > Time & Language.'
            }
            @{
                Name = '🔊 Fix Audio Tidak Bersuara'
                Desc = 'Restart layanan suara Windows (icon volume OK tapi bisu)'
                Type = 'fix'
                Cmds = @(
                    'net stop Audiosrv'
                    'net stop AudioEndpointBuilder'
                    'net start AudioEndpointBuilder'
                    'net start Audiosrv'
                )
                Note = 'Kalau masih bisu: cek Device Manager > Sound - kemungkinan driver bermasalah.'
            }
            @{
                Name = '⚡ Cek Power Plan Aktif'
                Desc = 'Skema hemat/performa energi saat ini'
                Type = 'check'
                Cmds = @(
                    'powercfg /getactivescheme'
                    'powercfg /list'
                )
            }
            @{
                Name = '⚡ Aktifkan High Performance'
                Desc = 'Skema performa tinggi untuk PC lambat'
                Type = 'fix'
                Cmds = @(
                    'powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
                    'powercfg /getactivescheme'
                )
                Note = 'Untuk laptop: baterai lebih cepat habis saat skema ini aktif.'
            }
            @{
                Name = '🧩 Cek Driver Bermasalah/Error'
                Desc = 'Hardware dengan driver rusak/tidak terpasang'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-PnpDevice -PresentOnly | Where-Object { $_.Status -ne ''OK'' } | Format-Table Status,Class,FriendlyName,InstanceId -AutoSize -Wrap"'
                )
                Note = 'Hasil kosong = semua driver perangkat aktif sehat.'
            }
            @{
                Name = '🖥️ Daftar Perangkat USB Terpasang'
                Desc = 'Flashdisk/printer/perangkat USB yang dikenali'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-PnpDevice -Class USB -PresentOnly | Format-Table FriendlyName,Status,InstanceId -AutoSize"'
                )
            }
            @{
                Name = '💀 Riwayat Blue Screen (BSOD Dump)'
                Desc = 'File dump crash untuk analisa penyebab blue screen'
                Type = 'check'
                Cmds = @(
                    'dir /a "C:\Windows\Minidump"'
                    'powershell -NoProfile -Command "Get-ChildItem ''C:\Windows\MEMORY.DMP'' -ErrorAction SilentlyContinue | Format-Table Name,Length,LastWriteTime -AutoSize"'
                )
                Note = 'Folder kosong/tidak ada = tidak pernah BSOD (atau dump dimatikan).'
            }
            @{
                Name = '⏳ Cek Perlu Restart (Pending Reboot)'
                Desc = 'Ada update/perbaikan yang menunggu restart?'
                Type = 'check'
                Cmds = @(
                    'reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing" /v RebootPending'
                    'reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"'
                    'reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v PendingFileRenameOperations'
                )
                Note = 'Error "unable to find" = tidak ada yang menunggu. Hasil muncul = PC perlu di-restart.'
            }
            @{
                Name = '🗂️ Lihat File HOSTS'
                Desc = 'Cek pemblokiran/bajakan domain (sering diubah malware)'
                Type = 'check'
                Cmds = @(
                    'type "C:\Windows\System32\drivers\etc\hosts"'
                )
                Note = 'Normalnya hanya berisi baris komentar (#). Entri aneh = perlu dicek.'
            }
            @{
                Name = '📦 Winget: Cek & Daftar Update App'
                Desc = 'Versi winget + aplikasi yang bisa di-upgrade'
                Type = 'check'
                Cmds = @(
                    'winget --version'
                    'winget upgrade'
                )
                Note = 'Jika "not recognized" = winget belum ada (install "App Installer" dari Microsoft Store).'
            }
            @{
                Name = '📦 Winget: Upgrade Semua Aplikasi ⏱️'
                Desc = 'Update semua aplikasi sekaligus secara senyap'
                Type = 'fix'
                Cmds = @(
                    'winget upgrade --all --silent --accept-source-agreements --accept-package-agreements'
                )
                Note = 'Butuh internet, 5-30 menit. Aplikasi yang punya updater sendiri bisa terlewat.'
            }
            @{
                Name = '📦 Winget: Install Aplikasi'
                Desc = 'Pasang aplikasi via ID, contoh: 7zip.7zip'
                Type = 'fix'
                Input = @(
                    @{ Prompt = 'ID aplikasi winget (contoh: 7zip.7zip):' }
                )
                Build = {
                    param($v)
                    @('winget install --id "' + $v[0] + '" -e --accept-source-agreements --accept-package-agreements')
                }
                Note = 'Cari ID di https://winget.run atau jalankan "winget search nama-aplikasi".'
            }
            @{
                Name = '🛒 Reset Cache Microsoft Store'
                Desc = 'wsreset - fix Store gagal buka/download/update'
                Type = 'open'
                Target = 'wsreset.exe'
            }
            @{
                Name = '🛒 Re-register Microsoft Store'
                Desc = 'Perbaiki Store yang rusak total (setelah wsreset)'
                Type = 'fix'
                Cmds = @(
                    'powershell -NoProfile -Command "Get-AppxPackage -AllUsers Microsoft.WindowsStore -ErrorAction SilentlyContinue | ForEach-Object { Add-AppxPackage -DisableDevelopmentMode -Register ($_.InstallLocation + ''\AppxManifest.xml'') -ErrorAction SilentlyContinue }; Write-Host ''Microsoft Store di-registrasi ulang - coba buka Store lagi.''"'
                )
            }
            @{
                Name = '🔋 Laporan Kesehatan Baterai'
                Desc = 'Report HTML: kapasitas desain vs kapasitas sekarang'
                Type = 'fix'
                Cmds = @(
                    'powercfg /batteryreport /output "%USERPROFILE%\Desktop\Battery-Report.html"'
                    'start "" "%USERPROFILE%\Desktop\Battery-Report.html"'
                )
                Note = 'Untuk laptop. Bandingkan DESIGN CAPACITY vs FULL CHARGE CAPACITY - jauh beda = baterai drop.'
            }
            @{
                Name = '🗄️ Backup Semua Driver (Sebelum Reinstall)'
                Desc = 'Ekspor driver third-party ke Desktop\Backup-Driver'
                Type = 'fix'
                Cmds = @(
                    'if not exist "%USERPROFILE%\Desktop\Backup-Driver" mkdir "%USERPROFILE%\Desktop\Backup-Driver"'
                    'dism /online /export-driver /destination:"%USERPROFILE%\Desktop\Backup-Driver"'
                )
                Note = 'Jalankan SEBELUM reinstall Windows - semua driver LAN/WiFi/printer terekspor, tinggal import lagi.'
            }
            @{
                Name = '🔑 Backup WiFi + Password (XML)'
                Desc = 'Ekspor semua profil WiFi ke Desktop\Backup-WiFi'
                Type = 'danger'
                Cmds = @(
                    'if not exist "%USERPROFILE%\Desktop\Backup-WiFi" mkdir "%USERPROFILE%\Desktop\Backup-WiFi"'
                    'netsh wlan export profile folder="%USERPROFILE%\Desktop\Backup-WiFi" key=clear'
                )
                Note = 'File XML berisi PASSWORD dalam bentuk terbuka - simpan/transfer dengan aman, hapus setelah dipakai.'
            }
            @{
                Name = '🔓 Take Ownership File/Folder'
                Desc = 'Penuhi hak akses Administrator - fix "Access Denied"'
                Type = 'danger'
                Input = @(
                    @{ Prompt = 'Path file/folder (contoh: C:\Users\User\Documents):' }
                )
                Build = {
                    param($v)
                    @(
                        ('takeown /f "' + $v[0] + '" /r /d y'),
                        ('icacls "' + $v[0] + '" /grant *S-1-5-32-544:F /t /c')
                    )
                }
                Note = 'Mengambil kepemilikan + grant full control ke group Administrator (via SID, aman di semua bahasa Windows).'
            }
            @{
                Name = '👁️ Tampilkan File Hidden + Ekstensi'
                Desc = 'Buka file tersembunyi & lihat ekstensi asli (.exe vs .pdf)'
                Type = 'fix'
                Cmds = @(
                    'reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f'
                    'reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f'
                    'taskkill /f /im explorer.exe'
                    'start explorer.exe'
                )
                Note = 'Penting saat investigasi malware (file penyamar). Balik ke default pakai tombol di bawah ini.'
            }
            @{
                Name = '🙈 Kembalikan View Explorer Default'
                Desc = 'Hidden disembunyikan + ekstensi disembunyikan lagi'
                Type = 'fix'
                Cmds = @(
                    'reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 0 /f'
                    'reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 1 /f'
                    'taskkill /f /im explorer.exe'
                    'start explorer.exe'
                )
            }
            @{
                Name = '🌙 Matikan Hibernasi (Hemat Ruang)'
                Desc = 'Hapus hiberfil.sys (beberapa GB) di drive C'
                Type = 'fix'
                Cmds = @(
                    'powercfg /h off'
                    'powershell -NoProfile -Command "Write-Host ''Hibernasi & Fast Startup dimatikan - hiberfil.sys terhapus.''"'
                )
                Note = 'Untuk aktifkan lagi pakai tombol di bawah ini.'
            }
            @{
                Name = '🌙 Aktifkan Hibernasi'
                Desc = 'Nyala-kan lagi hibernasi & fast startup'
                Type = 'fix'
                Cmds = @(
                    'powercfg /h on'
                    'powershell -NoProfile -Command "Write-Host ''Hibernasi aktif kembali.''"'
                )
            }
        )
    }
    @{
        Key   = 'account'
        Title = '👤 User & Akun'
        Items = @(
            @{
                Name = '👥 Daftar User Komputer'
                Desc = 'Semua akun user di PC ini'
                Type = 'check'
                Cmds = @(
                    'net user'
                )
            }
            @{
                Name = '🛡️ Group Lokal & Anggota Admin'
                Desc = 'Siapa saja yang punya hak Administrator'
                Type = 'check'
                Cmds = @(
                    'net localgroup'
                    'powershell -NoProfile -Command "Get-LocalGroupMember Administrators -ErrorAction SilentlyContinue | Format-Table Name,PrincipalSource,ObjectClass -AutoSize"'
                )
            }
            @{
                Name = '🔑 Reset Password User'
                Desc = 'Ganti password user tanpa password lama'
                Type = 'danger'
                Input = @(
                    @{ Prompt = 'Username yang password-nya mau direset:' }
                    @{ Prompt = 'Password baru:'; Password = $true }
                )
                Build  = {
                    param($v)
                    @('net user "' + $v[0] + '" "' + $v[1] + '"')
                }
                Note = 'User terkait harus login ulang dengan password baru.'
            }
            @{
                Name = '➕ Buat User Baru'
                Desc = 'Tambah akun user, bisa langsung jadi admin'
                Type = 'danger'
                Input = @(
                    @{ Prompt = 'Username baru:' }
                    @{ Prompt = 'Password:'; Password = $true }
                    @{ Prompt = 'Jadikan Administrator? (y/t):'; Default = 't' }
                )
                Build  = {
                    param($v)
                    $c = @('net user "' + $v[0] + '" "' + $v[1] + '" /add')
                    if ($v[2] -match '^[YyTt]') { $c += ('net localgroup Administrators "' + $v[0] + '" /add') }
                    $c
                }
            }
            @{
                Name = '🔓 Aktifkan Administrator Bawaan'
                Desc = 'Buka akun Administrator tersembunyi Windows'
                Type = 'danger'
                Cmds = @(
                    'net user Administrator /active:yes'
                )
                Note = 'Akun tanpa password muncul di login screen - isi password lewat tombol Reset Password.'
            }
            @{
                Name = '🔒 Nonaktifkan Administrator Bawaan'
                Desc = 'Sembunyikan lagi akun Administrator bawaan'
                Type = 'fix'
                Cmds = @(
                    'net user Administrator /active:no'
                )
            }
            @{
                Name = '🖥️ Aktifkan Remote Desktop (RDP)'
                Desc = 'Izinkan PC diremote dari komputer lain'
                Type = 'fix'
                Cmds = @(
                    'reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f'
                    'netsh advfirewall firewall set rule group="Remote Desktop" new enable=Yes'
                )
                Note = 'IP tujuan remote bisa dicek lewat tombol Info IP di tab Jaringan.'
            }
            @{
                Name = '🖥️ Nonaktifkan Remote Desktop'
                Desc = 'Tutup akses remote ke PC ini'
                Type = 'fix'
                Cmds = @(
                    'reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 1 /f'
                )
            }
            @{
                Name = '📌 IP Lokal (untuk Remote)'
                Desc = 'Lihat IP PC ini untuk dibackup dari komputer lain'
                Type = 'check'
                Cmds = @(
                    'ipconfig'
                )
            }
            @{
                Name = '⚙️ Buka Manajemen Komputer'
                Desc = 'User, disk, service, event viewer dalam 1 panel'
                Type = 'open'
                Target = 'compmgmt.msc'
            }
            @{
                Name = '👤 Buka User & Group Lokal (Pro)'
                Desc = 'Kelola user lanjutan - hanya Windows Pro'
                Type = 'open'
                Target = 'lusrmgr.msc'
            }
            @{
                Name = '🧑‍💻 User Login Aktif (quser)'
                Desc = 'Siapa saja yang sedang login (termasuk via RDP)'
                Type = 'check'
                Cmds = @(
                    'quser'
                    'qwinsta'
                )
                Note = 'Kolom ID dipakai untuk tombol Logoff User. quser tersedia di Windows Pro/Enterprise.'
            }
            @{
                Name = '🚪 Logoff User/Sesi'
                Desc = 'Keluarkan user dari sesi (pakai ID dari tombol quser)'
                Type = 'danger'
                Input = @(
                    @{ Prompt = 'ID sesi atau username (lihat quser):' }
                )
                Build = {
                    param($v)
                    @('logoff ' + $v[0])
                }
                Note = 'Perubahan yang belum di-save oleh user tersebut akan hilang!'
            }
            @{
                Name = '🔑 Wajib Ganti Password Saat Login'
                Desc = 'User harus ganti password sendiri di login berikutnya'
                Type = 'fix'
                Input = @(
                    @{ Prompt = 'Username:' }
                )
                Build = {
                    param($v)
                    @('net user "' + $v[0] + '" /logonpasswordchg:yes')
                }
                Note = 'Praktis untuk reset password user tanpa mengetahui password barunya.'
            }
            @{
                Name = '⬆️ User -> Group Administrator'
                Desc = 'Beri hak admin ke user yang sudah ada'
                Type = 'danger'
                Input = @(
                    @{ Prompt = 'Username yang mau dijadikan admin:' }
                )
                Build = {
                    param($v)
                    @('net localgroup Administrators "' + $v[0] + '" /add')
                }
            }
            @{
                Name = '🏢 Cek Status Domain & Kepercayaan'
                Desc = 'PC anggota domain? Hubungan aman ke domain server masih OK?'
                Type = 'check'
                Cmds = @(
                    'powershell -NoProfile -Command "$cs = Get-CimInstance Win32_ComputerSystem; Write-Host (''Domain        : '' + $cs.Domain); Write-Host (''Anggota domain: '' + $cs.PartOfDomain); if (-not $cs.PartOfDomain) { Write-Host ''PC ini WORKGROUP (bukan anggota domain).'' }"'
                    'powershell -NoProfile -Command "try { Write-Host (''Secure channel ke domain: '' + (Test-ComputerSecureChannel)) } catch { Write-Host ''Secure channel: tidak bisa dites (bukan anggota domain / butuh admin).'' }"'
                )
                Note = 'Secure channel False = trust rusak: re-join domain atau jalankan Test-ComputerSecureChannel -Repair.'
            }
        )
    }
    @{
        Key   = 'util'
        Title = '🧰 Utilitas'
        Items = @(
            @{ Name = '📊 Task Manager';              Desc = 'Kelola proses & performa';            Type = 'open'; Target = 'taskmgr' }
            @{ Name = '🧩 Device Manager';            Desc = 'Cek driver & hardware';               Type = 'open'; Target = 'devmgmt.msc' }
            @{ Name = '💾 Disk Management';           Desc = 'Kelola partisi drive';                Type = 'open'; Target = 'diskmgmt.msc' }
            @{ Name = '⚙️ Services Windows';          Desc = 'Daftar & kelola layanan';             Type = 'open'; Target = 'services.msc' }
            @{ Name = '📖 Event Viewer';              Desc = 'Log kejadian Windows';                Type = 'open'; Target = 'eventvwr.msc' }
            @{ Name = '🗄️ Registry Editor';           Desc = 'regedit (hati-hati!)';                Type = 'open'; Target = 'regedit' }
            @{ Name = '🖥️ Command Prompt (Admin)';    Desc = 'CMD manual di System32';              Type = 'open'; Target = 'cmd' }
            @{ Name = '🔷 PowerShell (Admin)';        Desc = 'Terminal PowerShell manual';          Type = 'open'; Target = 'powershell' }
            @{ Name = '🎛️ System Properties';         Desc = 'Nama PC, remote, restore point';      Type = 'open'; Target = 'sysdm.cpl' }
            @{ Name = '🌐 Network Connections';       Desc = 'Adapter WiFi/LAN (ncpa.cpl)';         Type = 'open'; Target = 'ncpa.cpl' }
            @{ Name = '📦 Program & Features';        Desc = 'Uninstall aplikasi';                  Type = 'open'; Target = 'appwiz.cpl' }
            @{ Name = '🚀 MSConfig';                  Desc = 'Boot, startup & layanan';             Type = 'open'; Target = 'msconfig' }
            @{ Name = '🏠 Control Panel';             Desc = 'Panel kontrol klasik';                Type = 'open'; Target = 'control' }
            @{ Name = '⏰ Task Scheduler';            Desc = 'Jadwal tugas otomatis';               Type = 'open'; Target = 'taskschd.msc' }
            @{ Name = '📈 Performance Monitor';       Desc = 'Monitoring performa detail';          Type = 'open'; Target = 'perfmon' }
            @{ Name = '📡 Resource Monitor';          Desc = 'CPU/RAM/disk/network real-time';      Type = 'open'; Target = 'resmon' }
            @{ Name = '🧠 Cek RAM (Restart)';         Desc = 'Windows Memory Diagnostic';           Type = 'open'; Target = 'mdsched.exe' }
            @{ Name = 'ℹ️ About PC (Settings)';       Desc = 'Spesifikasi & aktivasi Windows';      Type = 'open'; Target = 'ms-settings:about' }
            @{ Name = '🖼️ Display Settings';          Desc = 'Resolusi & monitor';                  Type = 'open'; Target = 'ms-settings:display' }
            @{ Name = '📦 Uninstall Apps (Settings)'; Desc = 'Daftar aplikasi modern';              Type = 'open'; Target = 'ms-settings:appsfeatures' }
            @{ Name = '🌐 Network Status (Settings)'; Desc = 'Status koneksi & data usage';         Type = 'open'; Target = 'ms-settings:network-status' }
            @{ Name = '🔗 Remote Desktop Client (mstsc)';  Desc = 'Koneksi RDP ke PC/server lain';   Type = 'open'; Target = 'mstsc' }
            @{ Name = '🤝 Remote Assistance (msra)';       Desc = 'Bantu/ dibantu via remote klasik'; Type = 'open'; Target = 'msra' }
            @{ Name = '🆘 Quick Assist';                   Desc = 'Remote bawaan Windows 10/11';     Type = 'open'; Target = 'shell:AppsFolder\MicrosoftCorporationII.QuickAssist_8wekyb3d8bbwe!QuickAssist' }
        )
    }
)

# ---------------------------------------------------------------------
# PERINTAH KUSTOM TIM (kustom.json) — opsional, untuk tim IT
# Format: [ { "Name":"...", "Desc":"...", "Type":"fix", "Cmds":["..."], "Note":"..." } ]
# Type  : check / fix / danger / open  (open memakai "Target":"app.exe")
# Salin CONTOH-kustom.json menjadi kustom.json lalu edit isinya.
# ---------------------------------------------------------------------
$KustomItems = @()
$KustomFile  = Join-Path $script:AppRoot 'kustom.json'
if (Test-Path $KustomFile) {
    try {
        $raw = Get-Content -Raw -Path $KustomFile | ConvertFrom-Json
        foreach ($k in @($raw)) {
            if (-not $k.Name) { continue }
            $t = [string]$k.Type
            if ($t -notin @('check', 'fix', 'danger', 'open')) { $t = 'check' }
            $kit = @{ Name = [string]$k.Name; Desc = [string]$k.Desc; Type = $t }
            if ($k.Note)   { $kit.Note = [string]$k.Note }
            if ($t -eq 'open') { $kit.Target = [string]$k.Target }
            else { $kit.Cmds = @($k.Cmds | ForEach-Object { [string]$_ }) }
            $KustomItems += $kit
        }
    } catch {
        $KustomItems = @()
        $script:KustomError = $_.Exception.Message
    }
}
if ($KustomItems.Count -gt 0) {
    $Categories += @{ Key = 'kustom'; Title = '🧩 Kustom (Tim)'; Items = $KustomItems }
}

# ---------------------------------------------------------------------
# KATALOG LINUX & MACOS (dijalankan lewat PowerShell Core / pwsh)
# Kategori ber-tag OS - hanya yang cocok dengan platform aktif yang tampil.
# ---------------------------------------------------------------------
$CategoriesNix = @(
    @{
        Key = 'nixnet'; OS = 'Linux'; Title = '🌐 Jaringan'
        Items = @(
            @{ Name = '📶 Info IP & Interface'; Desc = 'Alamat IP interface + tabel routing'; Type = 'check'; Cmds = @('ip -brief address', 'ip route') }
            @{ Name = '📶 Status WiFi & Koneksi'; Desc = 'Device & koneksi tersimpan (NetworkManager)'; Type = 'check'; Cmds = @('nmcli device status 2>/dev/null || echo "NetworkManager tidak berjalan"', 'nmcli connection show 2>/dev/null') }
            @{ Name = '🎯 Ping Host'; Desc = 'Ping ke host/IP yang Anda tentukan'; Type = 'check'; Input = @(@{ Prompt = 'Host / IP tujuan:'; Default = '8.8.8.8' }); Build = { param($v) @('ping -c 4 ' + $v[0]) } }
            @{ Name = '🗺️ Traceroute Host'; Desc = 'Lacak jalur koneksi (traceroute/tracepath)'; Type = 'check'; Input = @(@{ Prompt = 'Host / IP tujuan:'; Default = '8.8.8.8' }); Build = { param($v) @('traceroute ' + $v[0] + ' 2>/dev/null || tracepath ' + $v[0] + ' 2>/dev/null || echo "traceroute/tracepath belum terpasang"') } }
            @{ Name = '🔍 Tes DNS'; Desc = 'Resolve domain - diagnosa DNS'; Type = 'check'; Cmds = @('nslookup google.com 2>/dev/null || host google.com', 'getent hosts google.com') }
            @{ Name = '🔗 Port Listening (ss)'; Desc = 'Port & program yang membuka koneksi'; Type = 'check'; Cmds = @('ss -tulpn') }
            @{ Name = '🔌 Tes Port Host'; Desc = 'Cek port TCP terbuka tanpa tool tambahan'; Type = 'check'; Input = @(@{ Prompt = 'Host / IP:'; Default = '8.8.8.8' }, @{ Prompt = 'Port TCP:'; Default = '22' }); Build = { param($v) @('timeout 3 bash -c "</dev/tcp/' + $v[0] + '/' + $v[1] + '" && echo "Port ' + $v[1] + ' TERBUKA" || echo "Port ' + $v[1] + ' tertutup / host tidak dijawab"') } }
            @{ Name = '🧽 Flush DNS Cache'; Desc = 'Restart systemd-resolved / flush cache'; Type = 'fix'; Cmds = @('systemctl restart systemd-resolved 2>/dev/null || resolvectl flush-caches 2>/dev/null || echo "systemd-resolved tidak ditemukan"') }
            @{ Name = '🛠️ Restart Layanan Jaringan'; Desc = 'Restart NetworkManager / networking'; Type = 'fix'; Cmds = @('systemctl restart NetworkManager 2>/dev/null || systemctl restart networking 2>/dev/null || echo "layanan jaringan tidak ditemukan"') }
            @{ Name = '⚙️ Set IP Statik (nmcli)'; Desc = 'IP manual + gateway + DNS via NetworkManager'; Type = 'danger'; Input = @(@{ Prompt = 'Nama koneksi (nmcli con show):'; Default = 'Wired connection 1' }, @{ Prompt = 'IP statik (x.x.x.x):' }, @{ Prompt = 'Gateway:' }, @{ Prompt = 'DNS:'; Default = '8.8.8.8' }); Build = { param($v) @('nmcli con mod "' + $v[0] + '" ipv4.method manual ipv4.addresses ' + $v[1] + '/24 ipv4.gateway ' + $v[2] + ' ipv4.dns ' + $v[3]), ('nmcli con up "' + $v[0] + '"') }; Note = 'Prefix /24 dipakai. Lihat nama koneksi dulu lewat tombol Status WiFi & Koneksi.' }
        )
    }
    @{
        Key = 'nixsys'; OS = 'Linux'; Title = '🖥️ Sistem'
        Items = @(
            @{ Name = 'ℹ️ Info Sistem Lengkap'; Desc = 'Kernel, distro, hostname'; Type = 'check'; Cmds = @('uname -a', 'cat /etc/os-release', 'hostnamectl 2>/dev/null || true') }
            @{ Name = '🧩 Hardware CPU/RAM/Disk'; Desc = 'CPU, memori, dan block device'; Type = 'check'; Cmds = @('lscpu | head -14', 'free -h', 'lsblk') }
            @{ Name = '🔥 Proses Pemakan Resource Teratas'; Desc = 'Top 10 proses by CPU & RAM'; Type = 'check'; Cmds = @('ps aux --sort=-%cpu | head -12', 'ps aux --sort=-%mem | head -12') }
            @{ Name = '⚙️ Layanan yang Berjalan'; Desc = 'systemd service state running'; Type = 'check'; Cmds = @('systemctl list-units --type=service --state=running --no-pager') }
            @{ Name = '📜 Log Error Terbaru (journal)'; Desc = '30 error terakhir dari journald'; Type = 'check'; Cmds = @('journalctl -p err -n 30 --no-pager') }
            @{ Name = '🧱 Log Kernel Error/Warning'; Desc = 'dmesg level error & warning'; Type = 'check'; Cmds = @('dmesg --level=err,warn 2>/dev/null | tail -30 || echo "dmesg butuh sudo di distro ini"') }
            @{ Name = '🔁 Riwayat Reboot'; Desc = 'Kapan saja PC di-restart'; Type = 'check'; Cmds = @('last reboot 2>/dev/null | head -10 || echo "last tidak tersedia"') }
            @{ Name = '📦 Daftar Update Paket Tersedia'; Desc = 'apt/dnf/zypper auto-detect'; Type = 'check'; Cmds = @('if command -v apt >/dev/null 2>&1; then sudo apt update -qq && apt list --upgradable 2>/dev/null | head -25; elif command -v dnf >/dev/null 2>&1; then dnf check-update | head -25; elif command -v zypper >/dev/null 2>&1; then zypper lu; else echo "package manager tidak dikenali"; fi') }
            @{ Name = '🧱 Status Firewall (ufw/firewalld)'; Desc = 'Cek firewall aktif & rule terbuka'; Type = 'check'; Cmds = @('sudo ufw status verbose 2>/dev/null || sudo firewall-cmd --list-all 2>/dev/null || echo "ufw/firewalld tidak ditemukan"') }
            @{ Name = '🐳 Docker Containers'; Desc = 'Status container yang berjalan/ada'; Type = 'check'; Cmds = @('docker ps -a 2>/dev/null || echo "docker tidak terpasang / service tidak berjalan"') }
            @{ Name = '⏰ Crontab User Ini'; Desc = 'Jadwal otomatis milik user saat ini'; Type = 'check'; Cmds = @('crontab -l 2>/dev/null || echo "tidak ada crontab untuk user ini"') }
        )
    }
    @{
        Key = 'nixdisk'; OS = 'Linux'; Title = '💾 Disk'
        Items = @(
            @{ Name = '💾 Kapasitas Drive (df)'; Desc = 'Ruang terpakai/bebas semua mount'; Type = 'check'; Cmds = @('df -h --total 2>/dev/null || df -h') }
            @{ Name = '📊 Folder /var Paling Besar'; Desc = 'Pemboros ruang di /var (log/cache)'; Type = 'check'; Cmds = @('du -xsh /var/* 2>/dev/null | sort -rh | head -10') }
            @{ Name = '🩺 Kesehatan Disk (SMART)'; Desc = 'Butuh paket smartmontools'; Type = 'check'; Cmds = @('for d in $(lsblk -dno NAME | grep -E "^(sd|nvme)" | head -3); do echo "== /dev/$d =="; sudo smartctl -H "/dev/$d" 2>/dev/null | tail -4 || echo "smartmontools belum terpasang"; done') }
            @{ Name = '🗂️ Partisi & Filesystem'; Desc = 'lsblk -f + mount aktif'; Type = 'check'; Cmds = @('lsblk -f', 'findmnt | tail -15') }
        )
    }
    @{
        Key = 'nixupd'; OS = 'Linux'; Title = '🔄 Update & Bersih'
        Items = @(
            @{ Name = '📦 Cek Update OS'; Desc = 'apt/dnf/zypper auto-detect'; Type = 'check'; Cmds = @('if command -v apt >/dev/null 2>&1; then sudo apt update && apt list --upgradable 2>/dev/null | head -20; elif command -v dnf >/dev/null 2>&1; then dnf check-update | head -20; else echo "package manager tidak dikenali"; fi') }
            @{ Name = '⬆️ Upgrade Semua Paket ⏱️'; Desc = 'apt upgrade / dnf upgrade -y'; Type = 'fix'; Cmds = @('if command -v apt >/dev/null 2>&1; then sudo apt upgrade -y; elif command -v dnf >/dev/null 2>&1; then sudo dnf upgrade -y; else echo "package manager tidak dikenali"; fi'); Note = 'Butuh internet, bisa 5-30 menit.' }
            @{ Name = '🧹 Bersihkan Cache Paket & Log'; Desc = 'apt clean/autoremove + vacuum log 7 hari'; Type = 'fix'; Cmds = @('if command -v apt >/dev/null 2>&1; then sudo apt clean && sudo apt autoremove -y; elif command -v dnf >/dev/null 2>&1; then sudo dnf clean all; fi; sudo journalctl --vacuum-time=7d 2>/dev/null') }
        )
    }
    @{
        Key = 'nixusr'; OS = 'Linux'; Title = '👤 User'
        Items = @(
            @{ Name = '👥 Daftar User Biasa (UID 1000+)'; Desc = 'Akun user non-sistem di PC ini'; Type = 'check'; Cmds = @('awk -F: ''$3>=1000 && $3<65534 {print $1 " (UID " $3 ")"}'' /etc/passwd') }
            @{ Name = '➕ Buat User Baru'; Desc = 'useradd + set password (interaktif)'; Type = 'danger'; Input = @(@{ Prompt = 'Username baru:' }); Build = { param($v) @('sudo useradd -m -s /bin/bash ' + $v[0]), ('sudo passwd ' + $v[0]) }; Note = 'Password diminta interaktif di terminal setelah user dibuat.' }
            @{ Name = '🔑 Ganti Password User'; Desc = 'passwd interaktif untuk user tertentu'; Type = 'danger'; Input = @(@{ Prompt = 'Username:' }); Build = { param($v) @('sudo passwd ' + $v[0]) } }
            @{ Name = '⬆️ User -> Group sudo/wheel'; Desc = 'Beri hak admin (auto-detect nama group)'; Type = 'danger'; Input = @(@{ Prompt = 'Username:' }); Build = { param($v) @('sudo usermod -aG sudo ' + $v[0] + ' 2>/dev/null || sudo usermod -aG wheel ' + $v[0]) }; Note = 'Berlaku setelah user logout/login ulang.' }
        )
    }
    @{
        Key = 'macsys'; OS = 'MacOS'; Title = '🖥️ Sistem'
        Items = @(
            @{ Name = 'ℹ️ Info Sistem macOS'; Desc = 'Versi macOS + hardware'; Type = 'check'; Cmds = @('sw_vers', 'system_profiler SPHardwareDataType 2>/dev/null | head -18') }
            @{ Name = '🧩 Hardware & Resource'; Desc = 'CPU, jumlah core, memori'; Type = 'check'; Cmds = @('sysctl -n machdep.cpu.brand_string', 'sysctl -n hw.ncpu hw.memsize', 'top -l 1 -s 0 | grep -E "PhysMem|CPU usage"') }
            @{ Name = '🔥 Proses Teratas (CPU)'; Desc = '12 proses pemakan CPU terbesar'; Type = 'check'; Cmds = @('ps aux | sort -rk3 | head -12') }
            @{ Name = '🔁 Riwayat Boot & Uptime'; Desc = 'Uptime + boot terakhir'; Type = 'check'; Cmds = @('uptime', 'last reboot | head -6') }
            @{ Name = '🧰 Audit Launch Agents (Startup)'; Desc = 'Program yang jalan otomatis saat login'; Type = 'check'; Cmds = @('ls ~/Library/LaunchAgents/ 2>/dev/null || echo "(kosong)"', 'ls /Library/LaunchAgents/ 2>/dev/null || echo "(kosong)"') }
            @{ Name = '🧱 Status Application Firewall'; Desc = 'Firewall aplikasi bawaan macOS'; Type = 'check'; Cmds = @('sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "butuh sudo / tidak tersedia"') }
        )
    }
    @{
        Key = 'macnet'; OS = 'MacOS'; Title = '🌐 Jaringan'
        Items = @(
            @{ Name = '📶 Info Jaringan'; Desc = 'ifconfig + routing table'; Type = 'check'; Cmds = @('ifconfig', 'netstat -rn | head -20') }
            @{ Name = '📡 Layanan & Interface Aktif'; Desc = 'Daftar network service + status en0'; Type = 'check'; Cmds = @('networksetup -listallnetworkservices', 'ifconfig en0 | head -8') }
            @{ Name = '🎯 Ping Host'; Desc = 'Ping ke host/IP tertentu'; Type = 'check'; Input = @(@{ Prompt = 'Host / IP tujuan:'; Default = '8.8.8.8' }); Build = { param($v) @('ping -c 4 ' + $v[0]) } }
            @{ Name = '🔌 Tes Port Host'; Desc = 'Cek port TCP via nc'; Type = 'check'; Input = @(@{ Prompt = 'Host / IP:'; Default = '8.8.8.8' }, @{ Prompt = 'Port TCP:'; Default = '22' }); Build = { param($v) @('nc -z -G 3 ' + $v[0] + ' ' + $v[1] + ' 2>/dev/null && echo "Port ' + $v[1] + ' TERBUKA" || echo "Port ' + $v[1] + ' tertutup / host tidak dijawab"') } }
            @{ Name = '🧽 Flush DNS Cache'; Desc = 'Bersihkan cache DNS macOS'; Type = 'fix'; Cmds = @('sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder; echo "DNS cache macOS dibersihkan"') }
        )
    }
    @{
        Key = 'macdisk'; OS = 'MacOS'; Title = '💾 Disk'
        Items = @(
            @{ Name = '💾 Kapasitas Drive (df)'; Desc = 'Ruang terpakai/bebas'; Type = 'check'; Cmds = @('df -h') }
            @{ Name = '🗂️ Partisi & Disk (diskutil)'; Desc = 'Daftar disk & partisi'; Type = 'check'; Cmds = @('diskutil list') }
        )
    }
    @{
        Key = 'macupd'; OS = 'MacOS'; Title = '🔄 Update'
        Items = @(
            @{ Name = '📦 Cek Update macOS'; Desc = 'Daftar update software tersedia'; Type = 'check'; Cmds = @('softwareupdate -l') }
            @{ Name = '⬆️ Install Update macOS ⏱️'; Desc = 'Pasang semua update tersedia'; Type = 'fix'; Cmds = @('sudo softwareupdate -i -a'); Note = 'Butuh internet & bisa lama. Simpan pekerjaan dulu.' }
        )
    }
)

# ---------------------------------------------------------------------
# MESIN LINUX/MACOS: jalankan perintah shell via file .sh sementara
# ---------------------------------------------------------------------
function Invoke-NixShellJob {
    param([string]$Title, [string[]]$Cmds, [string]$Note, [switch]$Capture)
    $tmpDir = if ($env:TMPDIR) { $env:TMPDIR } else { '/tmp' }
    $stamp  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $shPath = Join-Path $tmpDir ("ITTK-{0}.sh" -f [guid]::NewGuid().ToString('N'))
    $lines  = @('#!/usr/bin/env bash') + $Cmds
    # LF saja (CRLF merusak script bash) + tanpa BOM
    [System.IO.File]::WriteAllText($shPath, (($lines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
    try {
        if ($Capture) {
            Write-Output ''
            Write-Output ('=' * 70)
            Write-Output (">> $Title   [$stamp]")
            Write-Output ('=' * 70)
            $text = (& bash $shPath 2>&1 | Out-String)
            Write-Output $text
            if ($Note) { Write-Output ("Catatan: " + $Note) }
            Write-Output "=== SELESAI ==="
            return $text
        } else {
            Write-Host ''
            Write-Host ('=' * 70) -ForegroundColor Cyan
            Write-Host (">> $Title   [$stamp]") -ForegroundColor Cyan
            Write-Host ('=' * 70) -ForegroundColor Cyan
            & bash $shPath
            if ($Note) { Write-Host ("`nCatatan: " + $Note) -ForegroundColor Yellow }
            Write-Host "`n=== SELESAI ===" -ForegroundColor Green
        }
    } finally {
        Remove-Item $shPath -ErrorAction SilentlyContinue
    }
}

function Start-TerminalToolkit {
    # Menu terminal interaktif untuk Linux/macOS (GUI WinForms tidak tersedia)
    $logDir = Join-Path $script:AppRoot 'Logs'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $logFile = Join-Path $logDir ('Log-{0:yyyyMMdd-HHmmss}.txt' -f (Get-Date))
    $cats = @($CategoriesNix | Where-Object { $_.OS -eq $osPlatform })
    $user = try { (whoami) } catch { '?' }
    $isRoot = ($user -eq 'root')
    while ($true) {
        Clear-Host
        Write-Host ('=' * 62) -ForegroundColor Cyan
        Write-Host ('  IT SUPPORT TOOLKIT - ' + $osPlatform + '  |  user: ' + $user) -ForegroundColor Cyan
        Write-Host ('=' * 62) -ForegroundColor Cyan
        if (-not $isRoot) { Write-Host '  Info: banyak perintah butuh sudo - idealnya jalankan ulang via: sudo pwsh -File IT-Support-Toolkit.ps1' -ForegroundColor Yellow }
        for ($i = 0; $i -lt $cats.Count; $i++) {
            Write-Host ('  [' + ($i + 1) + '] ' + (Remove-Emoji $cats[$i].Title) + '  (' + $cats[$i].Items.Count + ' perintah)')
        }
        Write-Host '  [x] Keluar'
        $pilih = Read-Host 'Pilih kategori (nomor) / x keluar'
        if ($pilih -match '^[xX]$') { break }
        if ($pilih -notmatch '^\d+$') { continue }
        $idx = [int]$pilih - 1
        if ($idx -lt 0 -or $idx -ge $cats.Count) { continue }
        $cat = $cats[$idx]

        Clear-Host
        Write-Host ('=== ' + (Remove-Emoji $cat.Title) + ' ===') -ForegroundColor Cyan
        for ($j = 0; $j -lt $cat.Items.Count; $j++) {
            $it = $cat.Items[$j]
            Write-Host ('  [' + ($j + 1) + '] [' + $it.Type.ToUpper() + '] ' + (Remove-Emoji $it.Name))
            Write-Host ('        ' + $it.Desc) -ForegroundColor DarkGray
        }
        Write-Host '  [b] Kembali'
        $pilihCmd = Read-Host 'Pilih perintah (nomor) / b kembali'
        if ($pilihCmd -match '^[bB]$') { continue }
        if ($pilihCmd -notmatch '^\d+$') { continue }
        $jdx = [int]$pilihCmd - 1
        if ($jdx -lt 0 -or $jdx -ge $cat.Items.Count) { continue }
        $item = $cat.Items[$jdx]

        if ($item.Type -eq 'danger') {
            $ok = Read-Host 'PERINTAH BERISIKO - lanjut? (y/t)'
            if ($ok -notmatch '^[yY]$') { continue }
        }
        $values = @()
        $batal = $false
        if ($item.Input) {
            foreach ($inp in $item.Input) {
                $hint = $inp.Prompt
                if ($inp.Default) { $hint += ' [' + $inp.Default + ']' }
                $v = Read-Host $hint
                if ([string]::IsNullOrWhiteSpace($v)) {
                    if ($inp.Default) { $v = $inp.Default }
                    elseif (-not $inp.AllowEmpty) { Write-Host 'Input kosong - dibatalkan.' -ForegroundColor Red; $batal = $true; break }
                }
                $values += $v
            }
            if ($batal) { continue }
        }
        $cmds = $item.Cmds
        if ($item.Build) { $cmds = & $item.Build $values }
        Invoke-NixShellJob -Title (Remove-Emoji $item.Name) -Cmds $cmds -Note $item.Note
        try { ("[" + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "] " + (Remove-Emoji $item.Name) + " :: " + ($cmds -join ' ; ')) | Add-Content -Path $logFile -Encoding UTF8 } catch {}
        Read-Host 'Enter untuk kembali ke menu'
    }
    Write-Host 'Toolkit ditutup. Log tersimpan di: ' $logFile -ForegroundColor Cyan
}

# ---------------------------------------------------------------------
# MODE SCRIPT (tanpa GUI): -List / -Run "nama"
# ---------------------------------------------------------------------
function Invoke-HeadlessItem {
    param($Item)
    if ($Item.Type -eq 'open') {
        Start-Process -FilePath $Item.Target
        Write-Output ("Dibuka: " + $Item.Target)
        return
    }
    if ($Item.Build) {
        Write-Output 'Perintah ini butuh input - jalankan lewat GUI.'
        return
    }
    $g   = [guid]::NewGuid().ToString('N')
    $bat = Join-Path $env:TEMP ("ITTK-$g.bat")
    $out = Join-Path $env:TEMP ("ITTK-$g.out")
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('@echo off')
    $lines.Add('(')
    foreach ($c in $Item.Cmds) { $lines.Add($c); $lines.Add('echo.') }
    $lines.Add('echo [ITTK-JOB-FINISHED]')
    $lines.Add(') > "' + $out + '" 2>&1')
    [System.IO.File]::WriteAllLines($bat, $lines)
    Write-Output ("`n=== " + $Item.Name + " ===")
    $p = Start-Process -FilePath $env:ComSpec -ArgumentList ('/c "' + $bat + '"') -WindowStyle Hidden -PassThru
    $p.WaitForExit()
    $text = [System.IO.File]::ReadAllText($out, [System.Text.Encoding]::GetEncoding(850))
    Write-Output $text
    if ($Item.Analysis) {
        try { $recs = @(& $Item.Analysis $text) } catch { $recs = @() }
        if ($recs.Count -gt 0) {
            Write-Output "`n=== REKOMENDASI ==="
            foreach ($r in $recs) { Write-Output ('  * ' + $r) }
        }
    }
    Remove-Item $bat, $out -ErrorAction SilentlyContinue
}

if ($List) {
    if ($osPlatform -eq 'Windows') {
        foreach ($cat in $Categories) {
            if ($cat.Key -eq 'fav') { continue }
            Write-Output ''
            Write-Output ("== " + $cat.Title + " ==")
            foreach ($it in $cat.Items) {
                Write-Output ("  [" + $it.Type.ToUpper() + "] " + $it.Name)
            }
        }
    } else {
        Write-Output ("Platform: " + $osPlatform + " (PowerShell Core)")
        foreach ($cat in ($CategoriesNix | Where-Object { $_.OS -eq $osPlatform })) {
            Write-Output ''
            Write-Output ("== " + $cat.Title + " ==")
            foreach ($it in $cat.Items) {
                Write-Output ("  [" + $it.Type.ToUpper() + "] " + $it.Name)
            }
        }
    }
    Write-Output ''
    exit
}

if ($Run) {
    if ($osPlatform -ne 'Windows') {
        $nixPool = @($CategoriesNix | Where-Object { $_.OS -eq $osPlatform })
        $nixFound = @()
        foreach ($cat in $nixPool) {
            foreach ($it in $cat.Items) {
                if ($it.Name -like ("*" + $Run + "*") -or ($it.Desc -and $it.Desc -like ("*" + $Run + "*"))) { $nixFound += $it }
            }
        }
        if ($nixFound.Count -eq 0) {
            Write-Output ("Perintah tidak ditemukan: " + $Run)
            Write-Output 'Gunakan -List untuk melihat daftar.'
            exit 1
        }
        $nixItem = $nixFound[0]
        if ($nixItem.Type -eq 'open') {
            $opener = if ($osPlatform -eq 'Linux') { 'xdg-open' } else { 'open' }
            & $opener $nixItem.Target
            exit
        }
        if ($nixItem.Build) {
            Write-Output 'Perintah ini butuh input - jalankan lewat menu terminal.'
            exit 1
        }
        Invoke-NixShellJob -Title (Remove-Emoji $nixItem.Name) -Cmds $nixItem.Cmds -Note $nixItem.Note -Capture | Write-Output
        exit
    }
    $found = @()
    foreach ($cat in $Categories) {
        foreach ($it in $cat.Items) {
            if ($it.Name -like ("*" + $Run + "*") -or ($it.Desc -and $it.Desc -like ("*" + $Run + "*"))) { $found += $it }
        }
    }
    if ($found.Count -eq 0) {
        Write-Output ("Perintah tidak ditemukan: " + $Run)
        Write-Output 'Gunakan -List untuk melihat daftar.'
        exit 1
    }
    Invoke-HeadlessItem $found[0]
    exit
}

# ---------------------------------------------------------------------
# WINDOWS : ELEVASI ADMINISTRATOR + GUI WINFORMS
# LINUX/MACOS : MENU TERMINAL INTERAKTIF (di atas sudah dieksekusi & exit)
# ---------------------------------------------------------------------
if ($osPlatform -ne 'Windows') {
    Start-TerminalToolkit
    exit
}

$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
            '-File', ('"{0}"' -f $PSCommandPath)
        )
    } catch {
        # User menolak UAC -> console ditutup dengan kode error
        exit 1
    }
    exit
}

# ---------------------------------------------------------------------
# INIT GUI
# ---------------------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Single-instance: cegah terbuka ganda ---
$mutexCreated = $false
$script:SingleMutex = New-Object System.Threading.Mutex($true, ('ITSupportToolkit-{0}' -f $env:USERNAME), [ref]$mutexCreated)
if (-not $mutexCreated) {
    [void][Windows.Forms.MessageBox]::Show('Toolkit sudah berjalan di sesi ini. Tutup jendela yang lama terlebih dahulu.', 'Sudah Terbuka', 'OK', 'Information')
    exit
}

[Windows.Forms.Application]::EnableVisualStyles()

$script:FontMono     = New-Object System.Drawing.Font('Consolas', 9)
$script:FontMonoBold = New-Object System.Drawing.Font('Consolas', 9, [System.Drawing.FontStyle]::Bold)

$script:Colors = @{
    check  = [System.Drawing.ColorTranslator]::FromHtml('#2B6CB0')  # biru
    fix    = [System.Drawing.ColorTranslator]::FromHtml('#C05621')  # oranye
    danger = [System.Drawing.ColorTranslator]::FromHtml('#C53030')  # merah
    open   = [System.Drawing.ColorTranslator]::FromHtml('#2F855A')  # hijau
}

# State job & log
$script:CurrentJob = $null
$script:JobQueue   = New-Object System.Collections.Queue
$script:LogDir     = Join-Path $script:AppRoot 'Logs'
if (-not (Test-Path $script:LogDir)) { New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null }
$script:LogFile    = Join-Path $script:LogDir ('Log-{0:yyyyMMdd-HHmmss}.txt' -f (Get-Date))

# Favorit & indeks katalog
$script:FavFile = Join-Path $script:AppRoot 'favorit.json'
$script:CatalogIndex = @{}
foreach ($cat in $Categories) { foreach ($it in $cat.Items) { $script:CatalogIndex[$it.Name] = $it } }

# ---------------------------------------------------------------------
# FUNGSI BANTU
# ---------------------------------------------------------------------
function Show-InputBox {
    param([string]$Title, [string]$Message, [string]$Default = '', [switch]$Password)
    $f = New-Object Windows.Forms.Form
    $f.Text = $Title
    $f.Size = '460,190'
    $f.FormBorderStyle = 'FixedDialog'
    $f.StartPosition = 'CenterParent'
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false
    $f.TopMost = $true
    $lbl = New-Object Windows.Forms.Label
    $lbl.Text = $Message
    $lbl.Location = '14,14'
    $lbl.Size = '420,40'
    $txt = New-Object Windows.Forms.TextBox
    $txt.Location = '14,62'
    $txt.Size = '420,24'
    $txt.Text = $Default
    if ($Password) { $txt.UseSystemPasswordChar = $true }
    $ok = New-Object Windows.Forms.Button
    $ok.Text = 'OK'
    $ok.Location = '254,104'
    $ok.Size = '84,30'
    $ok.DialogResult = 'OK'
    $no = New-Object Windows.Forms.Button
    $no.Text = 'Batal'
    $no.Location = '348,104'
    $no.Size = '84,30'
    $no.DialogResult = 'Cancel'
    $f.Controls.AddRange(@($lbl, $txt, $ok, $no))
    $f.AcceptButton = $ok
    $f.CancelButton = $no
    $r = $f.ShowDialog()
    $val = $txt.Text
    $f.Dispose()
    if ($r -eq 'OK') { return $val }
    return $null
}

function Toggle-Favorite {
    param($Item, [bool]$Add)
    $names = @()
    try {
        if (Test-Path $script:FavFile) { $names = @(Get-Content -Raw -Path $script:FavFile | ConvertFrom-Json) }
    } catch { $names = @() }
    $names = @($names | Where-Object { $_ })
    if ($Add) {
        if ($names -notcontains $Item.Name) { $names += $Item.Name }
    } else {
        $names = @($names | Where-Object { $_ -ne $Item.Name })
    }
    # Tulis manual sebagai JSON array - @()|ConvertTo-Json|Set-Content di PS 5.1
    # gagal senyap saat array kosong sehingga file tidak ikut ter-update.
    try {
        $json = '[' + (($names | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join ',') + ']'
        [System.IO.File]::WriteAllText($script:FavFile, $json, (New-Object System.Text.UTF8Encoding $true))
        Update-FavoritesTab
        $script:StatusLabel.Text = ('Favorit disimpan (' + $names.Count + ' perintah)')
    } catch {
        $script:StatusLabel.Text = ('Gagal menyimpan favorit: ' + $_.Exception.Message)
    }
}

function Update-FavoritesTab {
    if (-not $script:FavFlow) { return }
    $script:FavFlow.Controls.Clear()
    $names = @()
    try {
        if (Test-Path $script:FavFile) { $names = @(Get-Content -Raw -Path $script:FavFile | ConvertFrom-Json) }
    } catch { $names = @() }
    $names = @($names | Where-Object { $_ })
    if ($names.Count -eq 0) {
        $lb = New-Object Windows.Forms.Label
        $lb.Text = "Belum ada favorit.`nKlik kanan tombol perintah manapun -> ""Pin ke Favorit"" untuk menaruhnya di sini."
        $lb.AutoSize = $false
        $lb.Size = '600,56'
        $lb.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#9CDCFE')
        $script:FavFlow.Controls.Add($lb)
        return
    }
    foreach ($n in $names) {
        $it = $script:CatalogIndex[$n]
        if ($it) { Add-ToolButton -Flow $script:FavFlow -Item $it -TabTitle 'Favorit' }
    }
}

function Add-Output {
    param([string]$Text, [string]$ColorHex = '#D4D4D4', [switch]$Bold)
    $outBox.SelectionStart  = $outBox.TextLength
    $outBox.SelectionLength = 0
    $outBox.SelectionColor  = [System.Drawing.ColorTranslator]::FromHtml($ColorHex)
    if ($Bold) { $outBox.SelectionFont = $script:FontMonoBold } else { $outBox.SelectionFont = $script:FontMono }
    $outBox.AppendText($Text)
    $outBox.SelectionColor = $outBox.ForeColor
    $outBox.ScrollToCaret()
}

function Add-Log {
    param([string]$Title, [string]$Text)
    try {
        ("[" + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "] " + $Title + "`r`n" + $Text + "`r`n") |
            Add-Content -Path $script:LogFile -Encoding UTF8
    } catch {
        # Log gagal ditulis tidak boleh membuat GUI crash - abaikan senyap.
    }
}

function Invoke-Job {
    param([string]$Title, [string[]]$Cmds, [string]$Note, [string]$Kind, $JobItem = $null)
    if ($script:CurrentJob) {
        $script:JobQueue.Enqueue(@{ Title = $Title; Cmds = $Cmds; Note = $Note; Kind = $Kind; JobItem = $JobItem })
        Add-Output "`n[ANTREAN] Masuk antrean (masih menjalankan proses lain): $Title`n" '#CE9178'
        return
    }
    $g   = [guid]::NewGuid().ToString('N')
    $bat = Join-Path $env:TEMP ("ITTK-$g.bat")
    $out = Join-Path $env:TEMP ("ITTK-$g.out")
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('@echo off')
    $lines.Add('(')
    foreach ($c in $Cmds) { $lines.Add($c); $lines.Add('echo.') }
    $lines.Add('echo [ITTK-JOB-FINISHED]')
    $lines.Add(') > "' + $out + '" 2>&1')
    [System.IO.File]::WriteAllLines($bat, $lines)

    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Output ("`n" + ('=' * 72) + "`n>> $Title   [$stamp]`n" + ('=' * 72) + "`n") '#569CD6' $true
    Add-Output "Menjalankan via CMD ...`n" '#9CDCFE'

    $argStr = '/c "' + $bat + '"'
    try {
        $proc = Start-Process -FilePath $env:ComSpec -ArgumentList $argStr -WindowStyle Hidden -PassThru
    } catch {
        Add-Output ("Gagal memulai proses CMD: " + $_.Exception.Message + "`n") '#F48771'
        return
    }
    $script:CurrentJob = @{
        Proc = $proc; Title = $Title; OutFile = $out; BatFile = $bat
        Note = $Note; Kind = $Kind; Started = Get-Date
        Item = $JobItem; Cancelled = $false
    }
    $script:JobTimer.Start()
}

function Update-Jobs {
    if ($script:CurrentJob) {
        $j = $script:CurrentJob
        if ($j.Proc.HasExited) {
            $text = ''
            try {
                $text = [System.IO.File]::ReadAllText($j.OutFile, [System.Text.Encoding]::GetEncoding(850))
            } catch { $text = '' }
            if ([string]::IsNullOrWhiteSpace($text)) { $text = '(tidak ada output)' }
            Add-Output ($text.TrimEnd() + "`n") '#D4D4D4'
            $wasCancelled = [bool]$j.Cancelled
            if ($wasCancelled) {
                Add-Output "`n=== DIBATALKAN OLEH USER ===`n" '#F48771'
            } else {
                if ($j.Note) { Add-Output ("`nCatatan: " + $j.Note + "`n") '#DCDCAA' }
                Add-Output "`n=== SELESAI ===`n" '#6A9955'
            }
            Add-Log $j.Title $text
            try { Remove-Item $j.BatFile, $j.OutFile -ErrorAction SilentlyContinue } catch {}
            $script:CurrentJob = $null
            # Analisa hasil otomatis + aksi pasca-jalan (dilewati bila dibatalkan)
            if (-not $wasCancelled -and $j.Item) {
                if ($j.Item.Analysis) {
                    try { $recs = @(& $j.Item.Analysis $text) } catch { $recs = @() }
                    if ($recs.Count -gt 0) {
                        Add-Output "`n=== REKOMENDASI ===`n" '#C586C0'
                        foreach ($r in $recs) { Add-Output ('  * ' + $r + "`n") '#CE9178' }
                    }
                }
                if ($j.Item.PostRun) {
                    try { & $j.Item.PostRun $text } catch {
                        Add-Output ("Pasca-proses gagal: " + $_.Exception.Message + "`n") '#F48771'
                    }
                }
            }
        } else {
            $sec = [int]((Get-Date) - $j.Started).TotalSeconds
            $script:StatusLabel.Text = "$($j.Title) — berjalan ${sec}s ..."
        }
    }
    if (-not $script:CurrentJob) {
        if ($script:JobQueue.Count -gt 0) {
            $next = $script:JobQueue.Dequeue()
            Invoke-Job $next.Title $next.Cmds $next.Note $next.Kind $next.JobItem
        } else {
            $script:StatusLabel.Text = 'Siap — pilih perintah di tab atas'
            $script:JobTimer.Stop()
        }
    }
}

function Invoke-ToolkitItem {
    param($Item)
    # Buka aplikasi/panel
    if ($Item.Type -eq 'open') {
        try {
            Start-Process -FilePath $Item.Target
            $script:StatusLabel.Text = "Dibuka: $($Item.Target)"
        } catch {
            try { Start-Process -FilePath $env:ComSpec -ArgumentList ('/c start "" "' + $Item.Target + '"') } catch {
                [void][Windows.Forms.MessageBox]::Show("Tidak bisa membuka: $($Item.Target)", 'Gagal', 'OK', 'Error')
            }
        }
        return
    }
    # Konfirmasi untuk perintah berisiko + auto restore point
    if ($Item.Type -eq 'danger') {
        $rpInfo = if ($script:chkAutoRP.Checked) { "`n`n(Restore point akan dibuat otomatis dulu - bisa di-rollback.)" } else { '' }
        $r = [Windows.Forms.MessageBox]::Show(
            "TINDAKAN BERISIKO`n`n$($Item.Name)`n`n$($Item.Desc)$rpInfo`n`nLanjutkan?",
            'Konfirmasi', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
        if ($script:chkAutoRP.Checked) {
            # Restore point otomatis: masuk antrean lebih dulu, baru perintah berisiko
            $rpCmd = 'powershell -NoProfile -Command "Enable-ComputerRestore -Drive ''C:\'' -ErrorAction SilentlyContinue; reg add ''HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'' /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f | Out-Null; try { Checkpoint-Computer -Description ''IT-Toolkit-TKITEM'' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop; Write-Host ''Restore point berhasil dibuat (rollback tersedia via System Restore).'' } catch { Write-Host ''Restore point GAGAL dibuat - System Restore mungkin nonaktif di PC ini.''"'
            $rpCmd = $rpCmd.Replace('TKITEM', (Remove-Emoji $Item.Name))
            Invoke-Job -Title ('Auto Restore Point: ' + (Remove-Emoji $Item.Name)) -Cmds @($rpCmd) -Note '' -Kind 'check' -JobItem $null
        }
    }
    # Minta input bila perlu
    $values = @()
    if ($Item.Input) {
        foreach ($inp in $Item.Input) {
            $v = Show-InputBox -Title $Item.Name -Message $inp.Prompt -Default $inp.Default -Password:$inp.Password
            if ($null -eq $v) { return }
            if ([string]::IsNullOrWhiteSpace($v) -and -not $inp.AllowEmpty) {
                [void][Windows.Forms.MessageBox]::Show('Input tidak boleh kosong.', 'Dibatalkan', 'OK', 'Information')
                return
            }
            $values += $v
        }
    }
    $cmds = $Item.Cmds
    if ($Item.Build) { $cmds = & $Item.Build $values }
    Invoke-Job -Title $Item.Name -Cmds $cmds -Note $Item.Note -Kind $Item.Type -JobItem $Item
}

function Add-ToolButton {
    param($Flow, $Item, [string]$TabTitle = '')
    $btn = New-Object Windows.Forms.Button
    $btn.Size = '340,56'
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 0
    $btn.BackColor = $script:Colors[$Item.Type]
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.TextAlign = 'MiddleLeft'
    $btn.Padding = '10,0,0,0'
    $btn.Margin = '4,4,4,4'
    $btn.Cursor = 'Hand'
    # GDI WinForms tidak mendukung emoji -> bersihkan dari nama tombol
    $cleanName = Remove-Emoji $Item.Name
    $Item._search = ($cleanName + ' ' + $Item.Desc).ToLower()
    $Item._tab = $TabTitle
    $btn.Text = $cleanName + "`n" + $Item.Desc
    $btn.UseMnemonic = $false
    $btn.Tag = $Item
    $script:tooltip.SetToolTip($btn, $Item.Desc)
    $btn.Add_Click({ Invoke-ToolkitItem $this.Tag })
    $btn.ContextMenuStrip = $script:cmBtn
    $Flow.Controls.Add($btn)
    $script:AllButtons += $btn
}

function New-Tab {
    param([string]$Title, [string]$Intro)
    $cleanTitle = Remove-Emoji $Title
    $page = New-Object Windows.Forms.TabPage
    $page.Text = $cleanTitle
    $page.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#252526')
    $page.Padding = '8,8,8,8'
    $flow = New-Object Windows.Forms.FlowLayoutPanel
    $flow.Dock = 'Fill'
    $flow.AutoScroll = $true
    $flow.WrapContents = $true
    $flow.Padding = '6,6,6,6'
    if ($Intro) {
        $lb = New-Object Windows.Forms.Label
        $lb.Text = $Intro
        $lb.AutoSize = $true
        $lb.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#9CDCFE')
        $lb.Margin = '4,8,4,8'
        $flow.Controls.Add($lb)
        $flow.SetFlowBreak($lb, $true)
    }
    $page.Controls.Add($flow)
    return @($page, $flow)
}

# ---------------------------------------------------------------------
# BANGUN UI
# ---------------------------------------------------------------------
$form = New-Object Windows.Forms.Form
$form.Text = "IT Support Toolkit — $env:COMPUTERNAME  [Administrator]"
$form.Size = '1020,790'
$form.MinimumSize = '900,650'
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$form.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#1E1E1E')

# --- Kembalikan posisi/ukuran window dari sesi sebelumnya ---
$posFile = Join-Path $script:AppRoot 'posisi.json'
try {
    if (Test-Path $posFile) {
        $p = Get-Content -Raw -Path $posFile | ConvertFrom-Json
        $scr = [Windows.Forms.Screen]::PrimaryScreen.Bounds
        if ($p.X -ge -50 -and $p.X -lt ($scr.Width - 200) -and $p.Y -ge -50 -and $p.Y -lt ($scr.Height - 200)) {
            $form.StartPosition = 'Manual'
            $form.Location = ('{0},{1}' -f $p.X, $p.Y)
            if ($p.W -ge 900 -and $p.H -ge 650) { $form.Size = ('{0},{1}' -f $p.W, $p.H) }
        }
    }
} catch {
    # Posisi tersimpan tidak valid - pakai posisi default di tengah layar.
}

# --- Tab kategori ---
$script:tooltip = New-Object Windows.Forms.ToolTip
$script:AllButtons = @()

# --- Shortcut keyboard: Ctrl+F = fokus pencarian, Esc = bersihkan pencarian ---
$form.KeyPreview = $true
$form.Add_KeyDown({
    if ($_.Control -and ($_.KeyCode -eq 'F')) {
        $txtSearch.Focus()
        $_.Handled = $true
    } elseif ($_.KeyCode -eq 'Escape') {
        $txtSearch.Text = ''
        $_.Handled = $true
    }
})
# Menu klik-kanan pada tombol: salin perintah CMD-nya
$script:cmBtn = New-Object Windows.Forms.ContextMenuStrip
$miCopyCmd = $script:cmBtn.Items.Add('Salin perintah CMD')
$miCopyCmd.Add_Click({
    $src = $script:cmBtn.SourceControl
    if ($src -and $src.Tag) {
        $it = $src.Tag
        if ($it.Type -eq 'open') { $cmdText = $it.Target }
        elseif ($it.Build) { $cmdText = '(perintah dibangun dari input saat tombol diklik)' }
        else { $cmdText = ($it.Cmds -join "`r`n") }
        try { [Windows.Forms.Clipboard]::SetText($cmdText); $script:StatusLabel.Text = 'Perintah disalin ke clipboard' } catch {}
    }
})
$miPin = $script:cmBtn.Items.Add('Pin ke Favorit')
$miPin.Add_Click({ Toggle-Favorite $script:cmBtn.SourceControl.Tag $true })
$miUnpin = $script:cmBtn.Items.Add('Lepas dari Favorit')
$miUnpin.Add_Click({ Toggle-Favorite $script:cmBtn.SourceControl.Tag $false })
$tabs = New-Object Windows.Forms.TabControl
$tabs.Dock = 'Fill'

foreach ($cat in $Categories) {
    $t = New-Tab -Title $cat.Title -Intro $cat.Intro
    foreach ($item in $cat.Items) { Add-ToolButton -Flow $t[1] -Item $item -TabTitle (Remove-Emoji $cat.Title) }
    $tabs.TabPages.Add($t[0])
    if ($cat.Key -eq 'fav') { $script:FavFlow = $t[1] }
}
Update-FavoritesTab

# --- Tab bantuan ---
$helpPage = New-Object Windows.Forms.TabPage
$helpPage.Text = 'Bantuan'
$helpPage.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#252526')
$HelpText = @'
IT SUPPORT TOOLKIT — PANDUAN SINGKAT

CARA PAKAI
  1. Pilih tab kategori di atas (Jaringan, Sistem, Disk, dll).
  2. Klik tombol perintah -> langsung dijalankan lewat CMD.
  3. Hasil muncul di panel bawah (bisa disalin / disimpan sebagai log).
  4. Proses yang masih jalan terlihat di bar bawah sampai "Selesai".
  5. Ketik di kotak pencarian untuk memfilter 160+ tombol perintah.
  6. Klik kanan tombol perintah -> "Pin ke Favorit" -> muncul di tab Favorit.
  7. CPU & RAM dipantau live di pojok kanan bawah.
  8. Ctrl+F = fokus pencarian, Esc = bersihkan pencarian.
  9. Centang "Mode Aman" (panel bawah) untuk menyembunyikan tombol merah
     saat toolkit dipinjamkan ke teknisi junior / didemokan ke client.

LEGENDA WARNA TOMBOL
  Biru    = Cek / Diagnosa (aman, tidak mengubah apa pun)
  Oranye  = Perbaikan (langsung mengeksekusi fix)
  Merah   = Berisiko (muncul konfirmasi dulu)
  Hijau   = Membuka aplikasi / pengaturan Windows

CATATAN PENTING
  * Toolkit berjalan sebagai Administrator (setujui dialog UAC saat dibuka).
  * Tombol "Batalkan" (panel bawah) menghentikan proses yang sedang berjalan.
  * "Auto Restore Point": sebelum perintah MERAH dijalankan, titik rollback
    dibuat otomatis (bisa dimatikan lewat centang di panel bawah).
  * Klik kanan tombol untuk menyalin perintah CMD-nya.
  * Reset Winsock / TCP-IP / DNS / Reset Update -> RESTART PC agar berlaku penuh.
  * Tombol bertanda (jam) berjalan lama: SFC, DISM, Full Scan, defrag,
    component cleanup. Tunggu sampai status bar kembali ke "Siap".
  * Semua hasil otomatis tersimpan di folder Logs\ di sebelah file toolkit.
  * Perintah berat diantrekan otomatis (satu per satu) - bersabar.

MODE SCRIPT UNTUK TEKNISI (di CMD/PowerShell)
  powershell -File IT-Support-Toolkit.ps1 -List
  powershell -File IT-Support-Toolkit.ps1 -Run "Ping"

KAMUS ERROR WINDOWS UMUM
  0x80070005   = Akses ditolak -> jalankan sebagai Administrator / file dipakai
                 program lain (fix: Take Ownership di tab Ekstra)
  0x80070002   = File tidak ditemukan -> sering: cache update bermasalah
                 -> tombol "Reset Cache Windows Update" (tab Update)
  0x8007007B   = Nama file/path salah -> periksa ejaan path
  0x800F0954   = DISM gagal ambil source -> cek internet / setting WSUS kantor
  0x8007000E   = Memori tidak cukup -> tutup aplikasi, restart PC
  0xC1900200   = PC tak memenuhi syarat upgrade -> cek "Cek Syarat Windows 11"
  "Access is denied"                = Hak akses kurang -> Take Ownership
  "The RPC server is unavailable"   = Layanan/jaringan tujuan mati
                                      -> cek layanan & koneksi target
  "Parameter set cannot be resolved"= Perintah butuh parameter wajib

TIPS CEPAT
  * Internet mati total?      -> Jaringan: Reset Winsock, lalu RESTART.
  * Situs tidak bisa dibuka?  -> Jaringan: Flush DNS / Set DNS Google.
  * Windows bermasalah?       -> Sistem: DISM lalu SFC.
  * Update gagal terus?       -> Update: Reset Cache Windows Update.
  * Dokumen print nyangkut?   -> Printer: Kosongkan Antrian Print.
'@
$helpBox = New-Object Windows.Forms.RichTextBox
$helpBox.Dock = 'Fill'
$helpBox.ReadOnly = $true
$helpBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#252526')
$helpBox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#D4D4D4')
$helpBox.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$helpBox.Text = $HelpText
$helpPage.Controls.Add($helpBox)
$tabs.TabPages.Add($helpPage)

# --- Panel output bawah ---
$outPanel = New-Object Windows.Forms.Panel
$outPanel.Dock = 'Bottom'
$outPanel.Height = 330
$outPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#1E1E1E')

$outBox = New-Object Windows.Forms.RichTextBox
$outBox.Dock = 'Fill'
$outBox.ReadOnly = $true
$outBox.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#141414')
$outBox.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#D4D4D4')
$outBox.Font = $script:FontMono
$outBox.Text = "Selamat datang di IT Support Toolkit.`r`nPilih tab di atas, lalu klik tombol perintah — langsung dijalankan via CMD.`r`nPerintah berat berjalan di background, pantau di bar bawah.`r`n"

$outToolbar = New-Object Windows.Forms.Panel
$outToolbar.Dock = 'Top'
$outToolbar.Height = 64
$outToolbar.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#2D2D30')

function New-SmallButton {
    param([string]$Text, [int]$X, [int]$W = 130)
    $b = New-Object Windows.Forms.Button
    $b.Text = $Text
    $b.Location = "$X,5"
    $b.Size = "$W,28"
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 1
    $b.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml('#555555')
    $b.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#3C3C3C')
    $b.ForeColor = [System.Drawing.Color]::White
    $b.Cursor = 'Hand'
    return $b
}
$btnCopy    = New-SmallButton -Text 'Salin Output'  -X 10  -W 100
$btnSave    = New-SmallButton -Text 'Simpan Log'    -X 116 -W 94
$btnClear   = New-SmallButton -Text 'Bersihkan'     -X 216 -W 88
$btnOpenLog = New-SmallButton -Text 'Buka Log'      -X 310 -W 84
$btnHist    = New-SmallButton -Text 'Riwayat'       -X 400 -W 78
$btnCancel  = New-SmallButton -Text 'Batalkan'      -X 484 -W 86
$btnCancel.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#A63C3C')
$script:chkAutoRP = New-Object Windows.Forms.CheckBox
$script:chkAutoRP.Text = 'Auto Restore Point (sebelum perintah berisiko)'
$script:chkAutoRP.Location = '14,36'
$script:chkAutoRP.AutoSize = $true
$script:chkAutoRP.Checked = $true
$script:chkAutoRP.ForeColor = [System.Drawing.Color]::White
$script:chkSafe = New-Object Windows.Forms.CheckBox
$script:chkSafe.Text = 'Mode Aman (sembunyikan tombol berisiko)'
$script:chkSafe.Location = '320,36'
$script:chkSafe.AutoSize = $true
$script:chkSafe.Checked = $false
$script:chkSafe.ForeColor = [System.Drawing.Color]::White
$script:chkSafe.Add_Click({
    # Catatan: hanya menyentuh tombol di tab yang sedang aktif (handle-nya pasti
    # sudah dibuat). Tab lain diterapkan saat dipilih via SelectedIndexChanged -
    # mengubah properti tombol di tab yang belum terealisasi crash tanpa pesan.
    try {
        $flow = $tabs.SelectedTab.Controls[0]
        foreach ($b in $flow.Controls) {
            if ($b.Tag -and $b.Tag.Type -eq 'danger') { $b.Enabled = -not $script:chkSafe.Checked }
        }
        if ($script:chkSafe.Checked) { $script:StatusLabel.Text = 'Mode Aman AKTIF - tombol berisiko dinonaktifkan (abu-abu)' }
        else { $script:StatusLabel.Text = 'Mode Aman dimatikan - tombol berisiko aktif kembali' }
    } catch {
        $script:StatusLabel.Text = ('Mode Aman gagal: ' + $_.Exception.Message)
    }
})
$tabs.Add_SelectedIndexChanged({
    try {
        if (-not $tabs.SelectedTab) { return }
        $flow = $tabs.SelectedTab.Controls[0]
        foreach ($b in $flow.Controls) {
            if ($b.Tag -and $b.Tag.Type -eq 'danger') { $b.Enabled = -not $script:chkSafe.Checked }
        }
    } catch {
        # Terapkan Mode Aman saat ganti tab bersifat best-effort.
    }
})
$btnExpSet = New-SmallButton -Text 'Export Setelan' -X 576 -W 112
$btnImpSet = New-SmallButton -Text 'Import Setelan' -X 694 -W 112
$btnExpSet.Add_Click({
    $files = @('favorit.json', 'posisi.json', 'kustom.json') | ForEach-Object { Join-Path $script:AppRoot $_ } | Where-Object { Test-Path $_ }
    if ($files.Count -eq 0) { $script:StatusLabel.Text = 'Belum ada setelan untuk diekspor'; return }
    $dstZip = Join-Path ([Environment]::GetFolderPath('Desktop')) ('IT-Toolkit-Setelan-{0:yyyyMMdd-HHmm}.zip' -f (Get-Date))
    try { Compress-Archive -Path $files -DestinationPath $dstZip -Force; $script:StatusLabel.Text = "Setelan diekspor: $dstZip" } catch { $script:StatusLabel.Text = ('Gagal: ' + $_.Exception.Message) }
})
$btnImpSet.Add_Click({
    $dlg = New-Object Windows.Forms.OpenFileDialog
    $dlg.Filter = 'Setelan Toolkit (*.zip)|*.zip'
    $dlg.Title = 'Pilih file setelan hasil Export'
    if ($dlg.ShowDialog() -eq 'OK') {
        try {
            Expand-Archive -Path $dlg.FileName -DestinationPath $script:AppRoot -Force
            Update-FavoritesTab
            $script:StatusLabel.Text = 'Setelan diimpor - restart toolkit utk kustom.json & posisi baru'
        } catch { $script:StatusLabel.Text = ('Gagal: ' + $_.Exception.Message) }
    }
})
$btnOpenLog.Add_Click({
    try { Start-Process explorer.exe -ArgumentList ('"' + $script:LogDir + '"') } catch {}
})
$btnHist.Add_Click({
    $logs = @(Get-ChildItem -Path $script:LogDir -Filter '*.txt' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    $f2 = New-Object Windows.Forms.Form
    $f2.Text = 'Riwayat Eksekusi (Log)'
    $f2.Size = '560,440'
    $f2.StartPosition = 'CenterParent'
    $f2.TopMost = $true
    $script:HistList = New-Object Windows.Forms.ListBox
    $script:HistList.Dock = 'Fill'
    $script:HistList.Font = New-Object System.Drawing.Font('Consolas', 9)
    if ($logs.Count -eq 0) { [void]$script:HistList.Items.Add('(belum ada log)') }
    foreach ($l in $logs) { [void]$script:HistList.Items.Add($l.LastWriteTime.ToString('yyyy-MM-dd HH:mm') + '  ' + $l.Name) }
    $p2 = New-Object Windows.Forms.Panel
    $p2.Dock = 'Top'
    $p2.Height = 40
    $p2.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#2D2D30')
    $b2 = New-SmallButton -Text 'Buka di Notepad' -X 10 -W 170
    $b2.Add_Click({
        $selName = [string]$script:HistList.SelectedItem
        if ($selName -and $selName -ne '(belum ada log)') {
            $nm = ($selName -split '  ')[-1]
            Start-Process notepad.exe (Join-Path $script:LogDir $nm)
        }
    })
    $p2.Controls.Add($b2)
    $f2.Controls.Add($script:HistList)
    $f2.Controls.Add($p2)
    [void]$f2.ShowDialog($form)
    $f2.Dispose()
})
$btnCancel.Add_Click({
    if ($script:CurrentJob -and -not $script:CurrentJob.Proc.HasExited) {
        $script:CurrentJob.Cancelled = $true
        try { Stop-Process -Id $script:CurrentJob.Proc.Id -Force -ErrorAction Stop } catch {}
        $script:StatusLabel.Text = 'Membatalkan proses yang berjalan ...'
    } else {
        $script:StatusLabel.Text = 'Tidak ada proses yang sedang berjalan'
    }
})
$btnCopy.Add_Click({
    try {
        [Windows.Forms.Clipboard]::SetText($outBox.Text)
        $script:StatusLabel.Text = 'Output disalin ke clipboard'
    } catch { $script:StatusLabel.Text = 'Gagal menyalin output' }
})
$btnSave.Add_Click({
    $dlg = New-Object Windows.Forms.SaveFileDialog
    $dlg.Filter = 'Text File (*.txt)|*.txt'
    $dlg.FileName = 'IT-Toolkit-Output-{0:yyyyMMdd-HHmmss}.txt' -f (Get-Date)
    if ($dlg.ShowDialog() -eq 'OK') {
        [System.IO.File]::WriteAllText($dlg.FileName, $outBox.Text, (New-Object System.Text.UTF8Encoding $true))
        $script:StatusLabel.Text = "Log tersimpan: $($dlg.FileName)"
    }
})
$btnClear.Add_Click({ $outBox.Clear(); $script:StatusLabel.Text = 'Output dibersihkan' })
$outToolbar.Controls.AddRange(@($btnCopy, $btnSave, $btnClear, $btnOpenLog, $btnHist, $btnCancel, $script:chkAutoRP, $script:chkSafe, $btnExpSet, $btnImpSet))

$outPanel.Controls.Add($outBox)      # diproses terakhir (fill sisa)
$outPanel.Controls.Add($outToolbar)  # diproses duluan (dock top)

# --- Status bar ---
$statusPanel = New-Object Windows.Forms.Panel
$statusPanel.Dock = 'Bottom'
$statusPanel.Height = 28
$statusPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#007ACC')
$script:StatusLabel = New-Object Windows.Forms.Label
$script:StatusLabel.Text = 'Siap — pilih perintah di tab atas'
$script:StatusLabel.ForeColor = [System.Drawing.Color]::White
$script:StatusLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$script:StatusLabel.Location = '10,5'
$script:StatusLabel.AutoSize = $true
$statusPanel.Controls.Add($script:StatusLabel)

# --- Meter CPU/RAM live (kanan status bar) ---
$script:StatusPerf = New-Object Windows.Forms.Label
$script:StatusPerf.Text = 'CPU --%  |  RAM -- GB'
$script:StatusPerf.ForeColor = [System.Drawing.Color]::White
$script:StatusPerf.Location = '830,6'
$script:StatusPerf.AutoSize = $true
$statusPanel.Controls.Add($script:StatusPerf)

$perfTimer = New-Object Windows.Forms.Timer
$perfTimer.Interval = 2000
$perfTimer.Add_Tick({
    try {
        $cpu = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop).PercentProcessorTime
        $os  = Get-CimInstance Win32_OperatingSystem -Property FreePhysicalMemory,TotalVisibleMemorySize
        $ramUsed = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory)/1MB,1)
        $ramTot  = [math]::Round($os.TotalVisibleMemorySize/1MB,1)
        $script:StatusPerf.Text = ('CPU ' + $cpu + '%  |  RAM ' + $ramUsed + '/' + $ramTot + ' GB')
    } catch {
        # Nilai perf tidak tersedia di sesi ini - biarkan indikator apa adanya.
    }
})
$perfTimer.Start()

# --- Header ---
$header = New-Object Windows.Forms.Panel
$header.Dock = 'Top'
$header.Height = 52
$header.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#202020')
$lbTitle = New-Object Windows.Forms.Label
$lbTitle.Text = 'IT SUPPORT TOOLKIT'
$lbTitle.Font = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)
$lbTitle.ForeColor = [System.Drawing.Color]::White
$lbTitle.Location = '14,10'
$lbTitle.AutoSize = $true
$header.Controls.Add($lbTitle)

# --- Strip pencarian perintah (panel terpisah agar render pasti muncul) ---
$searchPanel = New-Object Windows.Forms.Panel
$searchPanel.Dock = 'Top'
$searchPanel.Height = 40
$searchPanel.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#2D2D30')
$lbSearch = New-Object Windows.Forms.Label
$lbSearch.Text = 'Cari perintah:'
$lbSearch.ForeColor = [System.Drawing.Color]::White
$lbSearch.Location = '14,11'
$lbSearch.AutoSize = $true
$txtSearch = New-Object Windows.Forms.TextBox
$txtSearch.Location = '110,8'
$txtSearch.Size = '320,26'
$script:tooltip.SetToolTip($txtSearch, 'Ketik nama perintah, mis. dns / printer / sfc / wifi — hasil difilter otomatis')
$searchPanel.Controls.AddRange(@($lbSearch, $txtSearch))
$txtSearch.Add_TextChanged({
    $q = $txtSearch.Text.Trim().ToLower()
    $matchedTabs = @()
    $n = 0
    $firstBtn = $null
    foreach ($b in $script:AllButtons) {
        $vis = ($q.Length -eq 0) -or ($b.Tag._search.Contains($q))
        $b.Visible = $vis
        if ($vis -and $q.Length -gt 0) {
            $n++
            if ($matchedTabs -notcontains $b.Tag._tab) { $matchedTabs += $b.Tag._tab }
            if (-not $firstBtn) { $firstBtn = $b }
        }
    }
    if ($q.Length -gt 0) {
        if ($n -eq 0) {
            $script:StatusLabel.Text = 'Tidak ada perintah yang cocok'
        } else {
            # Catatan: properti Visible tombol di tab non-aktif selalu false,
            # jadi tab tujuan dilacak sendiri lewat $firstBtn (bukan Visible).
            $target = $tabs.TabPages | Where-Object { $_.Text -eq $firstBtn.Tag._tab } | Select-Object -First 1
            if ($target) { $tabs.SelectedTab = $target }
            $script:StatusLabel.Text = ('' + $n + ' perintah cocok di tab: ' + ($matchedTabs -join ', '))
        }
    } else {
        $script:StatusLabel.Text = 'Siap — pilih perintah di tab atas'
    }
})

# --- Timer job ---
$script:JobTimer = New-Object Windows.Forms.Timer
$script:JobTimer.Interval = 400
$script:JobTimer.Add_Tick({ Update-Jobs })

# --- Susun form (urutan add menentukan docking) ---
$form.Controls.Add($tabs)          # fill
$form.Controls.Add($outPanel)      # bottom (di atas status)
$form.Controls.Add($statusPanel)   # bottom paling bawah
$form.Controls.Add($searchPanel)   # top (di bawah header)
$form.Controls.Add($header)        # top

# Tampilkan
$form.Add_FormClosing({
    try {
        @{ X = $form.Location.X; Y = $form.Location.Y; W = $form.Size.Width; H = $form.Size.Height } |
            ConvertTo-Json | Set-Content -Path (Join-Path $script:AppRoot 'posisi.json') -Encoding UTF8
    } catch {
        # Penyimpanan posisi bersifat best-effort - jangan blokir penutupan aplikasi.
    }
})
try {
    Add-Output "Toolkit siap. Folder log: $script:LogFile`n" '#6A9955'
    [void]$form.ShowDialog()
} catch {
    $guiErr = $_.Exception.Message
    try { Add-Output ("`nERROR GUI: " + $guiErr + "`n") '#F48771'; Add-Log 'GUI Error' $guiErr } catch { Write-Output ("GUI error: " + $guiErr) }
}
$form.Dispose()
