# ================================================
# SystemHive Optimizer - ORCHESTRATOR (fő vezérlő)
# Verzió: 0.2 - Tiszta verzió, 2026.04.05
# ================================================

# === AUTO ADMIN ELEVATION ===
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Rendszergazdai jogok szükségesek - ujrainditas admin modban..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "SystemHive Optimizer - ORCHESTRATOR inditasa" -ForegroundColor Green

# 1. SCAN futtatasa
Write-Host "1/2 - Scanner futtatasa..." -ForegroundColor Cyan
& "$PSScriptRoot\SystemHiveScanner.ps1"

# 2. Osszefoglalo + kerdes
$JsonFile = "$env:TEMP\ScanResults.json"

if (Test-Path $JsonFile) {
    $Issues = Get-Content $JsonFile -Raw | ConvertFrom-Json
    $Total = ($Issues | Measure-Object).Count
    
    Write-Host "`nSCAN OSSZEFOGLALO" -ForegroundColor Green
    Write-Host "Talalt hibak osszesen: $Total db" -ForegroundColor Yellow
    Write-Host "(Reszletes lista: $JsonFile)" -ForegroundColor Gray
} 
else {
    Write-Host "Scan nem keszult el! Eloszor futtasd a Scanner-t." -ForegroundColor Red
    pause
    exit
}

$Choice = Read-Host "`nSzeretned elvegezni a takarítást? (Y = igen, N = nem)"

if ($Choice -eq "Y" -or $Choice -eq "y") {
    Write-Host "2/2 - Cleaner futtatasa..." -ForegroundColor Cyan
    & "$PSScriptRoot\SystemHiveCleaner.ps1"
    Write-Host "`nORCHESTRATOR KESZ - minden modul lefutott!" -ForegroundColor Green
} 
else {
    Write-Host "Takaritas kihagyva. Nyomj egy gombot a kilepeshez..." -ForegroundColor Gray
}

pause
