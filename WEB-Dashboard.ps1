# WEB-Dashboard.ps1 - Dashboard web lokal IT Support Toolkit v7.0
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
#  - Seluruh perintah BERISIKO (Type = danger) dan perintah interaktif (Input/Build)
#    sengaja TIDAK diekspos lewat antarmuka web.
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

# --- Muat perintah kustom tim (kustom.json) bila ada ---
$kustomPath = Join-Path $PSScriptRoot 'kustom.json'
if (Test-Path $kustomPath) {
    try {
        $rawK = Get-Content -Raw -Path $kustomPath | ConvertFrom-Json
        $kItems = @()
        foreach ($k in @($rawK)) {
            if (-not $k.Name) { continue }
            $osTag = if ($k.OS) { [string]$k.OS } else { 'Windows' }
            if ($osTag -ne 'Windows' -and $osTag -ne 'All') { continue }
            $t = [string]$k.Type
            if ($t -notin @('check', 'fix', 'danger', 'open')) { $t = 'check' }
            $kit = @{ Name = [string]$k.Name; Desc = [string]$k.Desc; Type = $t }
            if ($t -eq 'open') { $kit.Target = [string]$k.Target }
            else { $kit.Cmds = @($k.Cmds | ForEach-Object { [string]$_ }) }
            $kItems += $kit
        }
        if ($kItems.Count -gt 0) {
            $catalog += @{ Key = 'kustom'; Title = 'Kustom (Tim)'; Items = $kItems }
        }
    } catch {
        # Abaikan kustom.json tidak valid agar dashboard tetap berjalan.
    }
}

function Remove-EmojiW {
    param([string]$s)
    return ($s -replace '[\uD800-\uDBFF][\uDC00-\uDFFF]', '' -replace '[\u2000-\u2BFF\uFE0F]', '').Trim()
}

# --- Susun daftar perintah aman untuk web (exclude danger & perintah butuh input) ---
$webItems = New-Object System.Collections.Generic.List[object]
$webUiItems = @()
$id = 0
foreach ($cat in $catalog) {
    if ($cat.Key -eq 'fav') { continue }
    $catTitle = Remove-EmojiW $cat.Title
    foreach ($it in $cat.Items) {
        if ($it.Type -eq 'danger') { continue }
        if ($it.Build -or $it.Input) { continue }
        $nm = Remove-EmojiW $it.Name
        $itemObj = @{
            Id     = $id
            Cat    = $catTitle
            Name   = $nm
            Desc   = [string]$it.Desc
            Type   = [string]$it.Type
            Target = [string]$it.Target
            Cmds   = @($it.Cmds)
        }
        $webItems.Add($itemObj)
        $webUiItems += [PSCustomObject]@{
            Id   = [int]$id
            Cat  = [string]$catTitle
            Name = [string]$nm
            Desc = [string]$it.Desc
            Type = [string]$it.Type
        }
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
    foreach ($w in $webItems) { if ($w.Id -eq $ItemId) { $item = $w; break } }
    if (-not $item) { return @{ ok = $false; output = 'Perintah tidak ditemukan.' } }
    if ($item.Type -eq 'open') {
        $target = if ($item.Target) { $item.Target } elseif ($item.Cmds.Count -gt 0) { $item.Cmds[0] } else { '' }
        if (-not $target) { return @{ ok = $false; output = 'Target aplikasi tidak tersedia.' } }
        try {
            Start-Process -FilePath $target -ErrorAction Stop
            return @{ ok = $true; output = 'Dibuka di PC client: ' + $target }
        } catch {
            try {
                Start-Process -FilePath $env:ComSpec -ArgumentList ('/c start "" "' + $target + '"')
                return @{ ok = $true; output = 'Dibuka di PC client: ' + $target }
            } catch {
                return @{ ok = $false; output = 'Gagal membuka ' + $target + ': ' + $_.Exception.Message }
            }
        }
    }
    if (-not $item.Cmds -or $item.Cmds.Count -eq 0) {
        return @{ ok = $false; output = 'Perintah tidak memiliki instruksi eksekusi.' }
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
$catalogJson = ConvertTo-Json -InputObject $webUiItems -Depth 3 -Compress
$htmlTemplate = @'
<!DOCTYPE html>
<html lang="id"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>IT Support Toolkit - Web Dashboard</title>
<style>
*{box-sizing:border-box}
body{font-family:'Segoe UI',system-ui,sans-serif;background:#18181b;color:#e4e4e7;margin:0;padding:18px 20px}
.top{display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:12px;border-bottom:1px solid #2e2e34;padding-bottom:12px}
h1{color:#38bdf8;font-size:20px;margin:0}
.sub{color:#a1a1aa;font-size:12px;margin-top:4px}
.controls{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin-top:14px}
input#q{flex:1;min-width:240px;max-width:440px;padding:9px 12px;border-radius:6px;border:1px solid #3f3f46;background:#27272a;color:#f4f4f5;font-size:14px}
select#cat{padding:9px 10px;border-radius:6px;border:1px solid #3f3f46;background:#27272a;color:#f4f4f5;font-size:13px}
.legend{display:flex;gap:10px;font-size:12px;color:#a1a1aa;margin-left:auto}
.dot{display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:4px;vertical-align:middle}
.layout{display:grid;grid-template-columns:1.35fr 1fr;gap:18px;margin-top:16px;align-items:start}
@media(max-width:900px){.layout{grid-template-columns:1fr}}
.sec{margin-bottom:16px}
.sec h2{color:#93c5fd;font-size:13px;text-transform:uppercase;letter-spacing:.04em;border-bottom:1px solid #2e2e34;padding-bottom:5px;margin:0 0 8px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:8px}
.btn{display:block;width:100%;text-align:left;padding:10px 12px;border:0;border-radius:6px;color:#fff;cursor:pointer;font-size:13px;font-weight:600;line-height:1.35}
.btn:hover{filter:brightness(1.08)}
.btn small{display:block;opacity:.9;font-size:11px;font-weight:400;margin-top:3px}
.check{background:#2b6cb0}.fix{background:#c05621}.open{background:#2f855a}.danger{background:#c53030}
.btn:disabled{opacity:.5;cursor:wait}
.outwrap{position:sticky;top:16px;background:#111114;border:1px solid #2e2e34;border-radius:8px;padding:12px}
.outhead{display:flex;align-items:center;justify-content:space-between;margin-bottom:8px}
.outhead h2{color:#38bdf8;font-size:14px;margin:0}
.mini{background:#27272a;color:#e4e4e7;border:1px solid #3f3f46;border-radius:5px;padding:5px 10px;font-size:12px;cursor:pointer}
.mini:hover{background:#3f3f46}
#outbox{background:#09090b;border:1px solid #27272a;border-radius:6px;padding:12px;font-family:Consolas,monospace;font-size:12px;white-space:pre-wrap;word-break:break-word;min-height:260px;max-height:66vh;overflow:auto;line-height:1.45}
#status{color:#fde047;font-size:12px;margin-top:8px;min-height:16px}
</style></head><body>
<div class="top">
  <div>
    <h1>IT Support Toolkit - Web Dashboard</h1>
    <div class="sub">Dieksekusi sebagai Administrator di PC lokal. Perintah berisiko (merah) dan input interaktif tidak diekspos lewat web.</div>
  </div>
  <div class="legend">
    <span><i class="dot check"></i>Cek</span>
    <span><i class="dot fix"></i>Perbaiki</span>
    <span><i class="dot open"></i>Buka Panel</span>
  </div>
</div>
<div class="controls">
  <input id="q" placeholder="Cari perintah (mis. ping, dns, printer, office)..." oninput="render()">
  <select id="cat" onchange="render()"><option value="">Semua Kategori</option></select>
</div>
<div class="layout">
  <div id="content"></div>
  <div class="outwrap">
    <div class="outhead">
      <h2>Output Eksekusi</h2>
      <div style="display:flex;gap:6px">
        <button class="mini" onclick="copyOut()">Salin</button>
        <button class="mini" onclick="clearOut()">Bersihkan</button>
      </div>
    </div>
    <div id="outbox">Pilih perintah di sebelah kiri untuk menjalankan...</div>
    <div id="status"></div>
  </div>
</div>
<script>
const DATA = __CATALOG__;
function esc(s){return String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')}
(function initCats(){
  const sel = document.getElementById('cat');
  const seen = new Set();
  DATA.forEach(it => { if(!seen.has(it.Cat)){ seen.add(it.Cat); const o = document.createElement('option'); o.value = it.Cat; o.textContent = it.Cat; sel.appendChild(o); } });
})();
function render(){
  const q = document.getElementById('q').value.toLowerCase().trim();
  const cf = document.getElementById('cat').value;
  const cats = {};
  DATA.forEach(it => {
    if (cf && it.Cat !== cf) return;
    if (q && !(it.Name+' '+it.Desc+' '+it.Cat).toLowerCase().includes(q)) return;
    (cats[it.Cat] = cats[it.Cat] || []).push(it);
  });
  let h = '';
  for (const c in cats) {
    h += '<div class="sec"><h2>'+esc(c)+' ('+cats[c].length+')</h2><div class="grid">';
    cats[c].forEach(it => {
      h += '<button class="btn '+esc(it.Type)+'" onclick="run('+it.Id+',this)">'+esc(it.Name)+
           '<small>'+esc(it.Desc)+'</small></button>';
    });
    h += '</div></div>';
  }
  document.getElementById('content').innerHTML = h || '<p style="color:#a1a1aa">Tidak ada perintah cocok.</p>';
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
function copyOut(){
  if (navigator.clipboard) navigator.clipboard.writeText(document.getElementById('outbox').textContent);
  document.getElementById('status').textContent = 'Output disalin ke clipboard.';
}
function clearOut(){
  document.getElementById('outbox').textContent = '';
  document.getElementById('status').textContent = 'Output dibersihkan.';
}
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
Write-Host '  IT SUPPORT TOOLKIT v7.0 - WEB DASHBOARD AKTIF' -ForegroundColor Cyan
Write-Host ('=' * 62) -ForegroundColor Cyan
Write-Host ('  Buka di PC ini   : http://127.0.0.1:' + $port + '/?t=' + $token) -ForegroundColor Green
Write-Host ('  Token (wajib)    : ' + $token)
Write-Host ('  Perintah tersedia: ' + $webItems.Count + ' (danger & input interaktif tidak diekspos)')
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
