# AUDIT-Perintah.ps1 — Audit kualitas seluruh perintah IT Support Toolkit
# 1) Parse-check setiap command PowerShell tertanam (tanpa mengeksekusi)
# 2) bash -n setiap Cmds Linux/macOS (cek sintaks shell)
# 3) -RunChecks : jalankan semua perintah CHECK Windows headless (dengan timeout)
# Hasil: konsol + AUDIT-Report.txt
param(
    [switch]$RunChecks,
    [int]$TimeoutSec = 180
)

function Remove-EmojiT {
    param([string]$s)
    return ($s -replace '[\uD800-\uDBFF][\uDC00-\uDFFF]', '' -replace '[\u2000-\u2BFF\uFE0F]', '').Trim()
}

$src = Join-Path $PSScriptRoot 'IT-Support-Toolkit.ps1'
if (-not (Test-Path $src)) { Write-Host "File tidak ditemukan: $src"; exit 1 }

# --- Parse script utama ---
$tokens = $null; $errs = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($src, [ref]$tokens, [ref]$errs)
if ($errs.Count) {
    Write-Host "SCRIPT UTAMA ADA PARSE ERROR:" -ForegroundColor Red
    $errs | ForEach-Object { Write-Output ("  LINE {0}: {1}" -f $_.Extent.StartLineNumber, $_.Message) }
    exit 1
}
Write-Host "[OK] Parse script utama" -ForegroundColor Green

# --- Ambil katalog via AST (TANPA menjalankan script utama) ---
$assign = $ast.FindAll({ param($a) $a -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)
$catalog = @(); $nixCatalog = @()
foreach ($a in $assign) {
    $name = $a.Left.VariablePath.UserPath
    $rhs  = $a.Right.Expression.Extent.Text
    # Skip assignment gabungan (contoh: $Categories += @{...} untuk kustom)
    if ($name -eq 'Categories' -and $rhs -notmatch '\$Categories' -and $catalog.Count -eq 0) {
        $catalog = Invoke-Expression $rhs
    }
    if ($name -eq 'CategoriesNix' -and $nixCatalog.Count -eq 0) {
        $nixCatalog = Invoke-Expression $rhs
    }
}
$winCount = @($catalog | ForEach-Object { $_.Items.Count } | Measure-Object -Sum).Sum
$nixCount = @($nixCatalog | ForEach-Object { $_.Items.Count } | Measure-Object -Sum).Sum
Write-Host ("[OK] Katalog dimuat: Windows " + $winCount + " perintah, Linux/macOS " + $nixCount + " perintah")

$report = New-Object System.Collections.Generic.List[string]
$fail = 0

# --- 1) Parse-check command PowerShell tertanam ---
$psCount = 0
foreach ($cat in $catalog) {
    foreach ($it in $cat.Items) {
        if (-not $it.Cmds) { continue }
        foreach ($cmd in $it.Cmds) {
            if ($cmd -match 'powershell(\.exe)?\s+-NoProfile\s+-Command\s+"(.*)"\s*$') {
                $inner = $Matches[2] -replace '\\"', '"'
                $pt = $null; $pe = $null
                [void][System.Management.Automation.Language.Parser]::ParseInput($inner, [ref]$pt, [ref]$pe)
                $psCount++
                if ($pe.Count) {
                    $fail++
                    $msg = "PARSE-PS   | {0} | {1} | {2}" -f (Remove-EmojiT $cat.Title), (Remove-EmojiT $it.Name), $pe[0].Message
                    $report.Add($msg); Write-Host $msg -ForegroundColor Red
                }
            }
        }
    }
}
Write-Host ("[OK] Embedded PS command dicek: " + $psCount)

# --- 2) bash -n untuk Cmds Linux/macOS ---
$nixChecked = 0
foreach ($cat in $nixCatalog) {
    foreach ($it in $cat.Items) {
        if (-not $it.Cmds) { continue }
        $sh = Join-Path $env:TEMP ("ittk-audit-{0}.sh" -f [guid]::NewGuid().ToString('N'))
        [System.IO.File]::WriteAllText($sh, (($it.Cmds -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
        $out = & bash -n $sh 2>&1 | Out-String
        $code = $LASTEXITCODE
        Remove-Item $sh -ErrorAction SilentlyContinue
        $nixChecked++
        if ($code -ne 0) {
            $fail++
            $msg = "BASH-SYNTAX | {0} | {1} | {2}" -f $cat.Title, (Remove-EmojiT $it.Name), ($out.Trim())
            $report.Add($msg); Write-Host $msg -ForegroundColor Red
        }
    }
}
Write-Host ("[OK] Item Linux/macOS dicek: " + $nixChecked)

# --- 3) Jalankan perintah CHECK Windows (headless, dengan timeout) ---
if ($RunChecks) {
    foreach ($cat in $catalog) {
        foreach ($it in $cat.Items) {
            if ($it.Type -ne 'check') { continue }
            if ($it.Build) { continue }   # butuh input - hanya bisa via GUI
            $runName = ($it.Name -replace '[\uD800-\uDBFF][\uDC00-\uDFFF]', '' -replace '[\u2000-\u2BFF\uFE0F]', '').Trim()
            $job = Start-Job -ScriptBlock {
                param($s, $r)
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $s -Run $r 2>&1 | Out-String
            } -ArgumentList $src, $runName
            if (Wait-Job $job -Timeout $TimeoutSec) {
                $out = [string](Receive-Job $job)
                if ($out -match 'ParserError|is not recognized|CommandNotFoundException|FullyQualifiedErrorId') {
                    $fail++
                    $msg = "RUN-ERROR  | {0} | {1}" -f (Remove-EmojiT $cat.Title), $runName
                    $report.Add($msg); Write-Host $msg -ForegroundColor Red
                } elseif ([string]::IsNullOrWhiteSpace($out)) {
                    $msg = "KOSONG     | {0} | {1}" -f (Remove-EmojiT $cat.Title), $runName
                    $report.Add($msg); Write-Host $msg -ForegroundColor Yellow
                } else {
                    Write-Host ("OK         | " + $runName) -ForegroundColor Green
                }
            } else {
                Stop-Job $job
                $msg = "TIMEOUT    | {0} | {1} (>{2}s)" -f (Remove-EmojiT $cat.Title), $runName, $TimeoutSec
                $report.Add($msg); Write-Host $msg -ForegroundColor DarkYellow
            }
            Remove-Job $job -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- Ringkasan + simpan report ---
$total = $winCount + $nixCount
Write-Host ''
Write-Host ('=' * 60)
Write-Host ("RINGKASAN: total $total perintah | masalah: $fail")
Write-Host ('=' * 60)
$repPath = Join-Path $PSScriptRoot 'AUDIT-Report.txt'
$head = "AUDIT IT SUPPORT TOOLKIT - " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " | Total: $total | Masalah: $fail"
[System.IO.File]::WriteAllLines($repPath, @($head) + $report)
if ($fail -gt 0) { exit 1 } else { Write-Host "AUDIT BERSIH - report: $repPath" -ForegroundColor Green }
