# ================================================
# SystemHive Optimizer - ORCHESTRATOR (fő vezérlő)
# Verzió: 0.1 - 2026.04.05
# ================================================

# === AUTO ADMIN ELEVATION ===
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-Admin)) {
    Write-Host "🔄 Rendszergazdai jogok szükségesek – újraindítás admin módban..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "🚀 SystemHive Optimizer - ORCHESTRATOR indítása" -ForegroundColor Green

# 1. SCAN
Write-Host "1/2 - Scanner futtatása..." -ForegroundColor Cyan
& "$PSScriptRoot\SystemHiveScanner.ps1"

# 2. ÖSSZEFOGLALÓ + KÉRDÉS
$JsonFile = "$env:TEMP\ScanResults.json"
if (Test-Path $JsonFile) {
    $Issues = Get-Content $JsonFile | ConvertFrom-Json
    $Total = ($Issues | Measure-Object).Count
    Write-Host "`n📊 SCAN ÖSSZEFOGLALÓ" -ForegroundColor Green
    Write-Host "   Talált hibák: $Total db" -ForegroundColor Yellow
    Write-Host "   (Részletes lista a ScanResults.json fájlban)" -ForegroundColor Gray
} else {
    Write-Host "❌ Scan nem készült el!" -ForegroundColor Red
    pause
    exit
}

$Choice = Read-Host "`nSzeretnéd elvégezni a takarítást? (Y = igen, N = nem) [Y/N]"
if ($Choice -eq "Y") {
    Write-Host "2/2 - Cleaner futtatása..." -ForegroundColor Cyan
    & "$PSScriptRoot\SystemHiveCleaner.ps1"
    Write-Host "`n🎉 ORCHESTRATOR KÉSZ – minden modul lefutott!" -ForegroundColor Green
} else {
    Write-Host "👋 Takarítás kihagyva. Nyomj egy gombot a kilépéshez..." -ForegroundColor Gray
}
pause
