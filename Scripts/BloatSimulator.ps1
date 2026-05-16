# ================================================
# SystemHive Optimizer - BLOAT SIMULATOR
# Verzio: 0.5 - 2026.05
# Cel: Teszteleshez registry "elzsírosodás" szimulálása
# ================================================

param([int]$Cycles = 50)

# === ADMIN ELEVATION ===
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Rendszergazdai jogok szuksegesek. Ujrainditas admin modban..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Cycles $Cycles" -Verb RunAs
    exit
}

# === DUAL PATH KEZELES ===
$ProjectName = "SystemHive-Optimizer"
$InstalledPath = "C:\Windows\Scripts\$ProjectName"
$LocalRoot = Split-Path -Parent $PSScriptRoot

$Root = if (Test-Path $InstalledPath) { $InstalledPath } else { $LocalRoot }
$TempDir = Join-Path $Root "Temp"

if (-not (Test-Path $TempDir)) { 
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null 
}

Write-Host "SystemHive Optimizer - BLOAT SIMULATOR (0.5) inditasa..." -ForegroundColor Magenta
Write-Host "Cycles: $Cycles" -ForegroundColor Gray
Write-Host "Munkakonyvtar: $Root`n" -ForegroundColor Gray

$FakeApps = @("UltraOptimizer", "GameBoosterX", "SystemTunePro", "NetSpeedHack", "DriverUpdater2025", "CleanMasterFake", "RegistryFixer")
$FakeCompanies = @("ShadowTech", "EagleSoft", "QuantumByte", "NexusLabs", "VortexSolutions")

$Created = 0

# 1. Fake Uninstall bejegyzesek
Write-Host "1. Fake Uninstall bejegyzesek letrehozasa..." -NoNewline
foreach ($i in 1..$Cycles) {
    $AppName = $FakeApps[(Get-Random -Maximum $FakeApps.Count)]
    $Company = $FakeCompanies[(Get-Random -Maximum $FakeCompanies.Count)]
    
    $KeyName = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$AppName`_Fake_$i"
    
    if (-not (Test-Path $KeyName)) {
        New-Item -Path $KeyName -Force | Out-Null
        New-ItemProperty -Path $KeyName -Name "DisplayName" -Value "$AppName Pro" -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $KeyName -Name "DisplayVersion" -Value "1.4.$i" -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $KeyName -Name "Publisher" -Value $Company -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $KeyName -Name "UninstallString" -Value "C:\Program Files\$AppName\uninstall.exe" -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $KeyName -Name "InstallLocation" -Value "C:\Program Files\$AppName" -PropertyType String -Force | Out-Null
        $Created++
    }
}
Write-Host " $Created db kesz" -ForegroundColor Green

# 2. Fake SharedDLLs
Write-Host "2. Fake SharedDLLs bejegyzesek letrehozasa..." -NoNewline
$SharedDLLPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\SharedDLLs"
$FakeDLLs = @("fakehelper.dll", "optimcore32.dll", "sysboost64.dll")

foreach ($dll in $FakeDLLs) {
    $FakePath = "C:\Windows\System32\$dll"
    if (-not (Test-Path $FakePath)) {
        New-Item -Path $FakePath -ItemType File -Force | Out-Null
    }
    Set-ItemProperty -Path $SharedDLLPath -Name $FakePath -Value (Get-Random -Minimum 10 -Maximum 999) -Force
}
Write-Host " kesz" -ForegroundColor Green

# 3. Fake CLSID bejegyzesek
Write-Host "3. Fake CLSID bejegyzesek letrehozasa..." -NoNewline
for ($i = 1; $i -le 15; $i++) {
    $Guid = [System.Guid]::NewGuid().ToString("B")
    $CLSIDPath = "HKCR:\CLSID\$Guid"
    New-Item -Path $CLSIDPath -Force | Out-Null
    New-ItemProperty -Path $CLSIDPath -Name "(Default)" -Value "Fake $AppName Object" -Force | Out-Null
}
Write-Host " 15 db kesz" -ForegroundColor Green

Write-Host "`nBloat Simulator kesz! $Created + tobbi elemmel novelve a registry." -ForegroundColor Cyan
Write-Host "Futtasd a Scanner.ps1-t a problemak felderitesehez." -ForegroundColor White

# Logolas
$LogFile = Join-Path $TempDir "BloatSim_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
"$(Get-Date) - BloatSimulator lefuttatva $Cycles cycle-lel. $Created uninstall bejegyzes." | Out-File $LogFile -Encoding UTF8
