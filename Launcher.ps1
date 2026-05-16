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
    Write-Host "Rendszergazdai jogok szükségesek. Újraindítás admin módban..." -ForegroundColor Yellow
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
    Write-Host "FIGYELMEZTETÉS: Laptopon vagy és NINCS hálózati tápellátás!" -ForegroundColor Red
    Write-Host "A művelet csak csatlakoztatott töltővel futhat le biztonsággal." -ForegroundColor Red
    $choice = Read-Host "Mégis folytassuk? (Y/N)"
    if ($choice -notmatch '^Y') { exit }
}

# === ALTATÁS KIKAPCSOLÁSA ===
powercfg -change -monitor-timeout-ac 0
powercfg -change -standby-timeout-ac 0
Write-Host "Altatás kikapcsolva (AC módban)..." -ForegroundColor Gray

Write-Host "`n=== SystemHive Optimizer Launcher ===" -ForegroundColor Cyan
Write-Host "Projekt gyökér: $Root`n" -ForegroundColor White

# Bloat szimuláció (teszteléshez)
if ($SimulateBloat) {
    Write-Host "Bloat szimuláció futtatása..." -ForegroundColor Magenta
    & "$ScriptsDir\SystemHiveBloatSimulator.ps1"
}

# Sorrend: Scanner → Review → Cleaner
Write-Host "1. Scanner indítása..." -ForegroundColor Cyan
& "$ScriptsDir\SystemHiveScanner.ps1"

$JsonFile = Join-Path $TempDir "ScanResults.json"

if (Test-Path $JsonFile) {
    $Issues = Get-Content $JsonFile -Raw | ConvertFrom-Json
    $Total = ($Issues | Measure-Object).Count
    
    Write-Host "`nSCAN KÉSZ → $Total lehetséges probléma talált." -ForegroundColor Green
    
    if (-not $AutoClean) {
        $Choice = Read-Host "`nFuttassuk a Cleaner-t? (Y/N)"
        if ($Choice -notmatch '^Y') {
            Write-Host "Kilépés. A találatokat a Temp mappában találod." -ForegroundColor Yellow
            pause; exit
        }
    }
    
    Write-Host "2. Cleaner indítása..." -ForegroundColor Cyan
    & "$ScriptsDir\SystemHiveCleaner.ps1" -JsonPath $JsonFile
}
else {
    Write-Host "Scanner nem hozta létre a JSON-t!" -ForegroundColor Red
}

Write-Host "`nMinden kész. Köszönjük, hogy az RTS csapatot használod!" -ForegroundColor Green
pause
