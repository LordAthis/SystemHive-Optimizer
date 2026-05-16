# ================================================
# SystemHive Optimizer - LAUNCHER (fő indító)
# Verzió: 0.5 - 2026.05
# ================================================

param([switch]$SimulateBloat, [switch]$AutoClean)

# === ADMIN ELEVATION ===
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Rendszergazdai jogok szuksegesek. Ujrainditas admin modban..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -SimulateBloat:`$$SimulateBloat -AutoClean:`$$AutoClean" -Verb RunAs
    exit
}

$Root = $PSScriptRoot
$TempDir = Join-Path $Root "Temp"
$LogDir  = Join-Path $Root "Logs"
$ScriptsDir = Join-Path $Root "Scripts"
$DataDir = Join-Path $Root "Data"

# Mappák létrehozása
foreach ($dir in @($TempDir, $LogDir, $ScriptsDir, $DataDir)) {
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
}

# === AKKU + TÁP ELLENŐRZÉS ===
$Battery = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
if ($Battery -and $Battery.BatteryStatus -ne 2) {
    Write-Host "FIGYELMEZTETES: Laptopon vagy es NINCS halozati tapellatas!" -ForegroundColor Red
    Write-Host "A muvelet csak csatlakoztatott toltovel futhat le biztonsaggal." -ForegroundColor Red
    $choice = Read-Host "Megis folytassuk? (Y/N)"
    if ($choice -notmatch '^Y') { exit }
}

# === ALTATÁS KIKAPCSOLÁSA ===
powercfg -change -monitor-timeout-ac 0
powercfg -change -standby-timeout-ac 0
Write-Host "Altatas kikapcsolva (AC modban)..." -ForegroundColor Gray

Write-Host "`n=== SystemHive Optimizer Launcher ===" -ForegroundColor Cyan
Write-Host "Projekt gyoker: $Root`n" -ForegroundColor White

# Bloat szimuláció (teszteléshez)
if ($SimulateBloat) {
    Write-Host "Bloat szimulacio futtatasa..." -ForegroundColor Magenta
    & "$ScriptsDir\BloatSimulator.ps1"
}

# Sorrend: Scanner → Review → Cleaner
Write-Host "1. Scanner inditasa..." -ForegroundColor Cyan
& "$ScriptsDir\Scanner.ps1"

$JsonFile = Join-Path $TempDir "ScanResults.json"

if (Test-Path $JsonFile) {
    $Issues = Get-Content $JsonFile -Raw | ConvertFrom-Json
    $Total = ($Issues | Measure-Object).Count
    
    Write-Host "`nSCAN KESZ → $Total lehetseges problemat talalt." -ForegroundColor Green
    
    if (-not $AutoClean) {
        $Choice = Read-Host "`nFuttassuk a Cleaner-t? (Y/N)"
        if ($Choice -notmatch '^Y') {
            Write-Host "Kilepes. A talalatokat a Temp mappaban talalod." -ForegroundColor Yellow
            pause; exit
        }
    }
    
    Write-Host "2. Cleaner inditasa..." -ForegroundColor Cyan
    & "$ScriptsDir\Cleaner.ps1" -JsonPath $JsonFile
}
else {
    Write-Host "Scanner nem hozta letre a JSON-t!" -ForegroundColor Red
}

Write-Host "`nMinden kesz. Koszonjuk, hogy hasznalod! Kerlek kuld be, ha van eszreveteled!" -ForegroundColor Green
pause
