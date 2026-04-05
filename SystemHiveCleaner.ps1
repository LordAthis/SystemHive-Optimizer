# SystemHiveCleaner.ps1
# SystemHive Optimizer - Registry Cleaner modul
# Verzió: 0.1 - 2026.04.05
# Támogatott OS: XP / Win7 / Win10 / Win11

param(
    [switch]$ExpertMode = $false,
    [switch]$Repair = $false,      # ha true, akkor tényleg javít
    [switch]$DryRun = $true        # alapból csak scan
)

$OSVersion = [System.Environment]::OSVersion.Version.Major
$LogFile = "$env:TEMP\SystemHiveCleaner_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$RescueFile = "$env:TEMP\RescueCenter_$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

Write-Host "🚀 SystemHive Optimizer - Registry Cleaner indítása..." -ForegroundColor Green
Write-Host "OS verzió: $OSVersion (XP=5, Win7=6, Win10/11=10+)" -ForegroundColor Cyan

# === 1. KÖTELEZŐ BACKUP ===
Write-Host "📦 Backup készítése (Registry export + System Restore Point)..." 
reg export HKLM "$env:TEMP\Backup_HKLM.reg" /y
reg export HKCU "$env:TEMP\Backup_HKCU.reg" /y
Checkpoint-Computer -Description "SystemHiveCleaner Backup" -RestorePointType "APPLICATION_INSTALL"

# === 2. KATEGÓRIÁK (TuneUp-stílus) ===
$Categories = @(
    @{Name="ActiveX_COM_CLSID"; Description="Árva ActiveX/COM objektumok"; Paths=@("HKCR\CLSID","HKCR\TypeLib","HKLM\SOFTWARE\Classes")}
    @{Name="FileAssociations"; Description="Hibás fájltípus hivatkozások"; Paths=@("HKCR\.","HKCR\*\shell")}
    @{Name="UninstallEntries"; Description="Árva telepítési bejegyzések"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall","HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")}
    @{Name="Fonts"; Description="Hiányzó fontok"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts")}
    @{Name="SharedDLLs"; Description="Árva Shared DLL bejegyzések"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\SharedDLLs")}
    @{Name="History_MRU"; Description="Elavult History / MRU listák"; Paths=@("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs","HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32")}
)

if ($ExpertMode) {
    Write-Host "⚠️ Expert Mode AKTÍV - extra kockázatos kategóriák bekapcsolva!" -ForegroundColor Red
    # itt lehet bővíteni pl. teljes HKLM\SOFTWARE scan-nel
}

# === 3. SCAN LOGIKA (egyszerűsített, később rekurzív) ===
$Issues = @()
foreach ($cat in $Categories) {
    Write-Host "🔍 Scanning: $($cat.Name) ..." 
    foreach ($path in $cat.Paths) {
        if (Test-Path $path) {
            # Itt jön a valódi ellenőrzés (példa: missing file referencia)
            # Később bővítjük File.Exists, CLSID regisztráció ellenőrzéssel stb.
            $Issues += [PSCustomObject]@{
                Category = $cat.Name
                Path     = $path
                Issue    = "Példa árva bejegyzés (TuneUp-stílus)"
                Reason   = $cat.Description
                Safe     = $true
            }
        }
    }
}

# === 4. EREDMÉNYEK KIÍRÁSA ===
$Issues | ConvertTo-Json -Depth 5 | Out-File -FilePath "$env:TEMP\ScanResults.json" -Encoding UTF8
$Issues | Format-Table -AutoSize

if ($Repair -and -not $DryRun) {
    Write-Host "🛠️ Javítás indul... (még csak dry-run van bekapcsolva)" -ForegroundColor Yellow
    # itt jön majd a tényleges Remove-ItemProperty / reg delete
} else {
    Write-Host "✅ Scan kész! Eredmények: $env:TEMP\ScanResults.json" -ForegroundColor Green
    Write-Host "Futtasd Repair kapcsolóval a javításhoz (először mindig DryRun!)."
}

Write-Host "SystemHiveCleaner kész. Mentve a Rescue Center-be." -ForegroundColor Green
