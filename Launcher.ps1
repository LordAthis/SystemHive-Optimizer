# ================================================
# SystemHive Optimizer - LAUNCHER
# Verzio: 0.5 - 2026.05
# ================================================

param([switch]$SimulateBloat, [switch]$AutoClean)

# === ADMIN ELEVATION ===
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Rendszergazdai jogok szuksegesek. Ujrainditas admin modban..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -SimulateBloat:`$$SimulateBloat -AutoClean:`$$AutoClean" -Verb RunAs
    exit
}

# === DUAL PATH KEZELES ===
$ProjectName = "SystemHive-Optimizer"
$InstalledPath = "C:\Windows\Scripts\$ProjectName"
$LocalRoot = $PSScriptRoot

# Telepített mappa létrehozása / szinkron
if (-not (Test-Path $InstalledPath)) {
    New-Item -Path $InstalledPath -ItemType Directory -Force | Out-Null
    Copy-Item -Path "$LocalRoot\*" -Destination $InstalledPath -Recurse -Force -Exclude @("*.git*","*.md",".gitignore")
    Write-Host "Projekt telepítve ide: $InstalledPath" -ForegroundColor Green
}

# Mappák meghatározása (telepített verzió preferálása)
$Root = if (Test-Path $InstalledPath) { $InstalledPath } else { $LocalRoot }
$TempDir    = Join-Path $Root "Temp"
$LogDir     = Join-Path $Root "Logs"
$ScriptsDir = Join-Path $Root "Scripts"
$DataDir    = Join-Path $Root "Data"

foreach ($dir in @($TempDir, $LogDir, $ScriptsDir, $DataDir)) {
    if (-not (Test-Path $dir)) { 
        New-Item -Path $dir -ItemType Directory -Force | Out-Null 
    }
}

# === AKKU + TÁP ELLENŐRZÉS ===
$Battery = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
if ($Battery -and $Battery.BatteryStatus -ne 2) {
    Write-Host "FIGYELMEZTETES: Laptop es nincs halozati tapellatas!" -ForegroundColor Red
    $choice = Read-Host "Folytassuk igy is? (Y/N)"
    if ($choice -notmatch '^Y') { exit }
}

# === ALTATÁS KIKAPCSOLASA ===
powercfg -change -monitor-timeout-ac 0
powercfg -change -standby-timeout-ac 0

Write-Host "`n=== SystemHive Optimizer Launcher (0.5) ===" -ForegroundColor Cyan
Write-Host "Munkakonyvtar: $Root`n" -ForegroundColor Gray

# Futás sorrend
if ($SimulateBloat) {
    Write-Host "Bloat Simulator futtatasa..." -ForegroundColor Magenta
    & "$ScriptsDir\BloatSimulator.ps1"
}

Write-Host "1. Scanner inditasa..." -ForegroundColor Cyan
& "$ScriptsDir\Scanner.ps1"

$JsonFile = Join-Path $TempDir "ScanResults.json"

if (Test-Path $JsonFile) {
    $Issues = Get-Content $JsonFile -Raw | ConvertFrom-Json
    Write-Host "`nSCAN KESZ - Talalt problemak: $($Issues.Count) db" -ForegroundColor Green
    
    if (-not $AutoClean) {
        $Choice = Read-Host "`nFuttassuk a Cleaner-t? (Y/N)"
        if ($Choice -notmatch '^Y') {
            Write-Host "Megszakitva." -ForegroundColor Yellow
            pause
            exit
        }
    }
    
    Write-Host "2. Cleaner inditasa..." -ForegroundColor Cyan
    & "$ScriptsDir\Cleaner.ps1" -JsonPath $JsonFile
}

Write-Host "`nMinden muvelet kesz." -ForegroundColor Green
pause
