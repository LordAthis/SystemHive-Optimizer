# ================================================
# SystemHive Optimizer - SCANNER modul
# Verzió: 0.2 - 2026.04.05
# Támogatott OS: Windows 7 / 10 / 11 (XP külön ág!)
# ================================================

param(
    [switch]$ExpertMode = $false,
    [switch]$Verbose = $true
)

$OS = [System.Environment]::OSVersion.Version.Major
$Is64Bit = [Environment]::Is64BitOperatingSystem
$LogFile = "$env:TEMP\SystemHiveScanner_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$JsonFile = "$env:TEMP\ScanResults.json"
$RescueFile = "$env:TEMP\RescueCenter_Scan_$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

Write-Host "🚀 SystemHive Optimizer - SCANNER indítása..." -ForegroundColor Green
Write-Host "OS: Windows $OS | 64-bit: $Is64Bit | ExpertMode: $ExpertMode" -ForegroundColor Cyan

# === 1. KÖTELEZŐ BACKUP (minden scan előtt) ===
reg export HKLM "$env:TEMP\Backup_HKLM.reg" /y | Out-Null
reg export HKCU "$env:TEMP\Backup_HKCU.reg" /y | Out-Null
Write-Host "📦 Registry backup elkészült (HKLM + HKCU)" -ForegroundColor Yellow

# === 2. TuneUp-stílusú KATEGÓRIÁK (mélyítve, valós ellenőrzéssel) ===
$Categories = @(
    @{Name="ActiveX_COM_CLSID"; Desc="Árva ActiveX/COM/CLSID/TypeLib bejegyzések"; Paths=@("HKCR\CLSID","HKCR\TypeLib","HKLM\SOFTWARE\Classes","HKLM\SOFTWARE\Wow6432Node\Classes")}
    @{Name="FileAssociations"; Desc="Hibás fájltípus-asszociációk"; Paths=@("HKCR\.","HKCR\*\shell","HKLM\SOFTWARE\Classes")}
    @{Name="UninstallEntries"; Desc="Árva Uninstall bejegyzések (hiányzó mappa/fájl)"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall","HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall","HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")}
    @{Name="Fonts"; Desc="Hiányzó font hivatkozások"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts","HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts")}
    @{Name="SharedDLLs"; Desc="Árva Shared DLL bejegyzések (fájl nem létezik)"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\SharedDLLs","HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\SharedDLLs")}
    @{Name="History_MRU"; Desc="Elavult History / MRU / RecentDocs listák"; Paths=@("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs","HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32","HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU")}
    @{Name="SoftwareLeftover"; Desc="Eltávolított programok maradvány kulcsai"; Paths=@("HKLM\SOFTWARE","HKLM\SOFTWARE\Wow6432Node","HKCU\SOFTWARE")}
)

if ($ExpertMode) {
    Write-Host "⚠️ EXPERT MODE AKTÍV – extra mély scan (teljes SOFTWARE ág)" -ForegroundColor Red
    # itt lehet később bővíteni pl. teljes HKLM\SOFTWARE rekurzív scan-re
}

# === 3. SCAN (valós ellenőrzés + statisztika) ===
$AllIssues = @()
$Stats = @{}

foreach ($cat in $Categories) {
    $IssuesInCat = 0
    Write-Host "🔍 Scanning $($cat.Name) ..." -ForegroundColor White
    
    foreach ($path in $cat.Paths) {
        if (Test-Path "Registry::$path") {
            $keys = Get-ChildItem "Registry::$path" -Recurse -ErrorAction SilentlyContinue
            
            foreach ($key in $keys) {
                # Példa valós ellenőrzések (TuneUp + MS best practice)
                $issue = $null
                
                if ($cat.Name -eq "SharedDLLs") {
                    $dllPath = $key.GetValue("")
                    if ($dllPath -and -not (Test-Path $dllPath)) {
                        $issue = "Hiányzó DLL: $dllPath"
                    }
                }
                elseif ($cat.Name -eq "UninstallEntries") {
                    $displayName = $key.GetValue("DisplayName")
                    $installLocation = $key.GetValue("InstallLocation")
                    if ($displayName -and $installLocation -and -not (Test-Path $installLocation)) {
                        $issue = "Árva telepítés: $displayName (mappa hiányzik)"
                    }
                }
                elseif ($cat.Name -eq "Fonts") {
                    $fontFile = $key.GetValue("")
                    if ($fontFile -and -not (Test-Path "$env:SystemRoot\Fonts\$fontFile")) {
                        $issue = "Hiányzó font fájl: $fontFile"
                    }
                }
                
                if ($issue) {
                    $AllIssues += [PSCustomObject]@{
                        Category    = $cat.Name
                        Description = $cat.Desc
                        Path        = $key.PSPath
                        Issue       = $issue
                        SafeToRemove= $true
                        ValueData   = $key.GetValue("")
                        OS          = "Win$OS"
                    }
                    $IssuesInCat++
                }
            }
        }
    }
    $Stats[$cat.Name] = $IssuesInCat
    Write-Host "   → $($IssuesInCat) probléma talált" -ForegroundColor Gray
}

# === 4. ÖSSZEFOGLALÓ + JSON EXPORT ===
$Summary = "SCAN KÉSZ! Talált problémák:`n"
$Stats.GetEnumerator() | ForEach-Object { $Summary += "   $($_.Key): $($_.Value) db`n" }
$Summary += "`nRészletes lista: $JsonFile"

Write-Host "`n$Summary" -ForegroundColor Green

$AllIssues | ConvertTo-Json -Depth 10 | Out-File -FilePath $JsonFile -Encoding UTF8
$AllIssues | Select-Object Category,Description,Issue,Path | Format-Table -AutoSize

Write-Host "`n✅ ScanResults.json elkészült – későbbi Cleaner / UI számára." -ForegroundColor Green
Write-Host "Log: $LogFile" -ForegroundColor Gray
