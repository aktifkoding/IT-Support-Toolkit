# WEB-Dashboard.ps1 — Dashboard web lokal IT Support Toolkit
#
# Jalankan di PC yang sedang dirawat, lalu buka alamat (dengan token) dari
# HP/laptop lain di jaringan yang SAMA, atau dari browser di PC itu sendiri.
#
# KEAMANAN:
#  - Hanya listen di http://127.0.0.1:8098 (localhost) + token acak per sesi.
#  - Supaya bisa diakses dari HP, buka port-forward di PC itu, contoh:
#      netsh interface portproxy add v4tov4 listenport=8098 listenaddress=0.0.0.0 connectport=8098 connectaddress=127.0.0.1
#    lalu akses http://<IP-PC>:8098/?t=<token>. MATIKAN setelah selesai:
#      netsh interface portproxy delete v4tov4 listenport=8098 listenaddress=0.0.0.0
#  - Perintah DESTRUKTIF (matikan PC, reset total, dsb) sengaja TIDAK diekspos.
#  - Dashboard berjalan sebagai Administrator (self-elevate).

# --- Self-elevate ---
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $PSCommandPath)
    )
    exit
}

Add-Type -AssemblyName System.Windows.Forms

# --- Ambil katalog dari script utama via AST (tanpa menjalankannya) ---
$src = Join-Path $PSScriptRoot 'IT-Support-Toolkit.ps1'
if (-not (Test-Path $src)) { Write-Host "Script utama tidak ditemukan: $src"; Read-Host 'Enter'; exit 1 }
$tokens = $null; $errs = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($src, [ref]$tokens, [ref]$errs)
$assign = $ast.FindAll({ param($a) $a -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)
$catalog = @()
foreach ($a in $assign) {
    $name = $a.Left.VariablePath.UserPath
    $rhs  = $a.Right.Expression.Extent.Text
    if ($name -eq 'Categories' -and $rhs -notmatch '\$Categories' -and $catalog.Count -eq 0) {
        $catalog = Invoke-Expression $rhs
    }
}
function Remove-EmojiW {
    param([string]$s)
    return ($s -replace '[\uD800-\uDBFF][\uDC00-\uDFFF]', '' -replace '[\u2000-\u2BFF\uFE0F]', '').Trim()
}

# --- Susun daftar perintah untuk web (exclude destruktif) ---
$blacklist = @('Nuklir', 'Restart Komputer', 'Matikan Komputer', 'Advanced Startup', 'Jadwalkan CHKDSK', 'Kosongkan Log Event')
$webItems = New-Object System.Collections.Generic.List[object]
$id = 0
foreach ($cat in $catalog) {
    if ($cat.Key -eq 'fav') { continue }
    foreach ($it in $cat.Items) {
        $nm = Remove-EmojiW $it.Name
        $skip = $false
        foreach ($b in $blacklist) { if ($nm -like ("*" + $b + "*")) { $skip = $true } }
        if ($skip) { continue }
        $webItems.Add(@{
            Id   = $id
            Cat  = (Remove-EmojiW $cat.Title)
            Name = $nm
            Desc = $it.Desc
            Type = $it.Type
            Cmds = @($it.Cmds)
        })
        $id++
    }
}

$token  = [guid]::NewGuid().ToString('N').Substring(0, 12)
$port   = 8098
$logDir = Join-Path $PSScriptRoot 'Logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

# --- Eksekusi command via batch tersembunyi (pola sama dengan GUI) ---
function Invoke-WebCommand {
    param([int]$ItemId)
    $item = $null
    foreach ($w in $webItems) { if ($w.Id -eq $ItemId) { $item = $w } }
    if (-not $item) { return @{ ok = $false; output = 'Perintah tidak ditemukan.' } }
    if ($item.Type -eq 'open') {
        try { Start-Process -FilePath $item.Cmds[0] } catch {}
        return @{ ok = $true; output = 'Dibuka: ' + $item.Cmds[0] }
    }
    $g   = [guid]::NewGuid().ToString('N')
    $bat = Join-Path $env:TEMP ("ITTK-WEB-$g.bat")
    $out = Join-Path $env:TEMP ("ITTK-WEB-$g.out")
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('@echo off')
    $lines.Add('(')
    foreach ($c in $item.Cmds) { $lines.Add($c); $lines.Add('echo.') }
    $lines.Add(') > "' + $out + '" 2>&1')
    [System.IO.File]::WriteAllLines($bat, $lines)
    $p = Start-Process -FilePath $env:ComSpec -ArgumentList ('/c "' + $bat + '"') -WindowStyle Hidden -PassThru
    if (-not $p.WaitForExit(600000)) {
        try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch {}
        $text = 'TIMEOUT (10 menit) - perintah dihentikan.'
    } else {
        try { $text = [System.IO.File]::ReadAllText($out, [System.Text.Encoding]::GetEncoding(850)) } catch { $text = '' }
        if ([string]::IsNullOrWhiteSpace($text)) { $text = '(tidak ada output)' }
    }
    try {
        ("[" + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "] WEB: " + $item.Name + "`r`n" + $text + "`r`n") |
            Add-Content -Path (Join-Path $logDir 'Log-WEB.txt') -Encoding UTF8
    } catch {}
    Remove-Item $bat, $out -ErrorAction SilentlyContinue
    return @{ ok = $true; output = $text }
}

# --- HTML dashboard ---
$catalogJson = ConvertTo-Json -InputObject @($webItems) -Depth 4
$htmlTemplate = @'
<!DOCTYPE html>
<html lang="id"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>IT Support Toolkit - Web</title>
<style>
body{font-family:Segoe UI,sans-serif;background:#1e1e1e;color:#d4d4d4;margin:0;padding:16px}
h1{color:#4fc1ff;font-size:20px;margin:0 0 4px}
.sub{color:#9cdcfe;font-size:12px;margin-bottom:12px}
input#q{width:100%;max-width:420px;padding:8px;border-radius:6px;border:1px solid #444;background:#252526;color:#eee;font-size:14px}
.sec{margin-top:18px}
.sec h2{color:#c586c0;font-size:14px;border-bottom:1px solid #333;padding-bottom:4px}
.btn{display:block;width:100%;text-align:left;margin:4px 0;padding:8px 10px;border:0;border-radius:6px;color:#fff;cursor:pointer;font-size:13px}
.btn small{display:block;opacity:.85;font-size:11px}
.check{background:#2b6cb0}.fix{background:#c05621}
.btn:disabled{opacity:.5;cursor:wait}
#out{margin-top:16px}
#outbox{background:#141414;border:1px solid #333;border-radius:6px;padding:12px;font-family:Consolas,monospace;font-size:12px;white-space:pre-wrap;word-break:break-word;min-height:60px;max-height:50vh;overflow:auto}
#status{color:#dcdcaa;font-size:12px;margin-top:8px;min-height:16px}
</style></head><body>
<h1>IT Support Toolkit - Web</h1>
<div class="sub">PC ini dieksekusi sebagai Administrator. Perintah destruktif tidak diekspos lewat web.</div>
<input id="q" placeholder="Cari perintah..." oninput="filter()">
<div id="content"></div>
<div id="out"><h2 style="color:#4fc1ff;font-size:14px">Output</h2><div id="outbox">Pilih perintah di atas...</div><div id="status"></div></div>
<script>
const DATA = __CATALOG__;
function esc(s){return s.replace(/&/g,'&amp;').replace(/</g,'&lt;')}
function render(){
  const q = document.getElementById('q').value.toLowerCase();
  const cats = {};
  DATA.forEach(it => {
    if (q && !(it.Name+' '+it.Desc).toLowerCase().includes(q)) return;
    (cats[it.Cat] = cats[it.Cat] || []).push(it);
  });
  let h = '';
  for (const c in cats) {
    h += '<div class="sec"><h2>'+esc(c)+'</h2>';
    cats[c].forEach(it => {
      h += '<button class="btn '+it.Type+'" onclick="run('+it.Id+',this)">'+esc(it.Name)+
           '<small>'+esc(it.Desc)+'</small></button>';
    });
    h += '</div>';
  }
  document.getElementById('content').innerHTML = h || '<p>Tidak ada perintah cocok.</p>';
}
async function run(id, btn){
  btn.disabled = true;
  document.getElementById('status').textContent = 'Menjalankan... (perintah berat bisa 1-10 menit, jangan tutup halaman)';
  document.getElementById('outbox').textContent = 'Menunggu hasil...';
  try {
    const r = await fetch('/api/run?t=__TOKEN__&id='+id);
    const j = await r.json();
    document.getElementById('outbox').textContent = j.output;
  } catch(e) { document.getElementById('outbox').textContent = 'Gagal: '+e; }
  document.getElementById('status').textContent = 'Selesai.';
  btn.disabled = false;
}
function filter(){render()}
render();
</script></body></html>
'@

$html = $htmlTemplate.Replace('__CATALOG__', $catalogJson).Replace('__TOKEN__', $token)

# --- HttpListener ---
try {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add(('http://127.0.0.1:' + $port + '/'))
    $listener.Start()
} catch {
    Write-Host ("Gagal membuka port " + $port + ": " + $_.Exception.Message) -ForegroundColor Red
    Read-Host 'Enter untuk tutup'
    exit 1
}

Write-Host ''
Write-Host ('=' * 62) -ForegroundColor Cyan
Write-Host '  IT SUPPORT TOOLKIT - WEB DASHBOARD AKTIF' -ForegroundColor Cyan
Write-Host ('=' * 62) -ForegroundColor Cyan
Write-Host ('  Buka di PC ini   : http://127.0.0.1:' + $port + '/?t=' + $token) -ForegroundColor Green
Write-Host ('  Token (wajib)    : ' + $token)
Write-Host ('  Perintah tersedia: ' + $webItems.Count + ' (destruktif tidak diekspos)')
Write-Host '  Dari HP/PC lain  : butuh port-forward (lihat komentar di atas file)'
Write-Host '  Tekan Ctrl+C untuk berhenti.' -ForegroundColor Yellow
Write-Host ''

try { Start-Process ('http://127.0.0.1:' + $port + '/?t=' + $token) } catch {}

while ($listener.IsListening) {
    $ctx  = $listener.GetContext()
    $req  = $ctx.Request
    $res  = $ctx.Response
    $qt   = [string]$req.QueryString['t']
    if ($qt -ne $token) {
        $res.StatusCode = 403
        $b = [Text.Encoding]::UTF8.GetBytes('403 - Token tidak valid.')
        $res.OutputStream.Write($b, 0, $b.Length); $res.OutputStream.Close()
        continue
    }
    $path = $req.Url.AbsolutePath
    try {
        if ($path -eq '/api/run') {
            $rid = 0
            [void][int]::TryParse([string]$req.QueryString['id'], [ref]$rid)
            $r = Invoke-WebCommand -ItemId $rid
            $json = ConvertTo-Json -InputObject $r -Compress
            $res.ContentType = 'application/json; charset=utf-8'
            $b = [Text.Encoding]::UTF8.GetBytes($json)
        } else {
            $res.ContentType = 'text/html; charset=utf-8'
            $b = [Text.Encoding]::UTF8.GetBytes($html)
        }
        $res.StatusCode = 200
    } catch {
        $res.StatusCode = 500
        $b = [Text.Encoding]::UTF8.GetBytes(('500 - ' + $_.Exception.Message))
    }
    $res.OutputStream.Write($b, 0, $b.Length)
    $res.OutputStream.Close()
}
