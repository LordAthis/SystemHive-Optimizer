# ================================================
# SystemHive Optimizer - SCANNER modul (finomított v0.3)
# Verzió: 0.3 - 2026.04.05
# Támogatott OS: Windows 7 / 10 / 11
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

$LogFile = "$env:TEMP\SystemHiveScanner_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$JsonFile = "$env:TEMP\ScanResults.json"

Write-Host "🚀 SystemHive Optimizer - SCANNER indítása (mélyített scan)..." -ForegroundColor Green

# === BACKUP ===
reg export HKLM "$env:TEMP\Backup_HKLM.reg" /y | Out-Null
reg export HKCU "$env:TEMP\Backup_HKCU.reg" /y | Out-Null
Write-Host "📦 Registry backup kész (HKLM + HKCU)" -ForegroundColor Yellow

# === MÉLYÍTETT KATEGÓRIÁK (TuneUp + extra valós ellenőrzések) ===
$Categories = @(
    @{Name="ActiveX_COM_CLSID"; Desc="Árva ActiveX/COM/CLSID/TypeLib"; Paths=@("HKCR\CLSID","HKCR\TypeLib","HKLM\SOFTWARE\Classes","HKLM\SOFTWARE\Wow6432Node\Classes")}
    @{Name="FileAssociations"; Desc="Hibás fájltípus-asszociációk"; Paths=@("HKCR\.","HKCR\*\shell","HKLM\SOFTWARE\Classes")}
    @{Name="UninstallEntries"; Desc="Árva telepítési bejegyzések (hiányzó fájl/mappa)"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall","HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall","HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")}
    @{Name="Fonts"; Desc="Hiányzó font fájlok"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts","HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts")}
    @{Name="SharedDLLs"; Desc="Árva Shared DLL bejegyzések"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\SharedDLLs","HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\SharedDLLs")}
    @{Name="History_MRU"; Desc="Elavult History / MRU / RecentDocs"; Paths=@("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs","HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32","HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU")}
    @{Name="StartupPrograms"; Desc="Startup bejegyzések hiányzó exe-re"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run","HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce","HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run","HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce")}
    @{Name="ContextMenu_ShellEx"; Desc="Árva Context Menu / Shell Extension handler-ek"; Paths=@("HKCR\*\shellex\ContextMenuHandlers","HKCR\Directory\shellex\ContextMenuHandlers","HKCR\Folder\shellex\ContextMenuHandlers")}
    @{Name="SoftwareLeftover"; Desc="Eltávolított programok maradvány kulcsai (ismert minták)"; Paths=@("HKLM\SOFTWARE","HKLM\SOFTWARE\Wow6432Node","HKCU\SOFTWARE")}
)

$AllIssues = @()
$Stats = @{}

foreach ($cat in $Categories) {
    $IssuesInCat = 0
    Write-Host "🔍 Scanning $($cat.Name) ..." -ForegroundColor White
    
    foreach ($path in $cat.Paths) {
        if (Test-Path "Registry::$path") {
            $keys = Get-ChildItem "Registry::$path" -Recurse -ErrorAction SilentlyContinue -Depth 5  # mélység korlátozva a sebesség miatt
            
            foreach ($key in $keys) {
                $issue = $null
                $valueData = $key.GetValue("")
                
                # === MÉLYÍTETT ELLENŐRZÉSEK ===
                if ($cat.Name -eq "SharedDLLs" -and $valueData -and -not (Test-Path $valueData)) {
                    $issue = "Hiányzó DLL: $valueData"
                }
                elseif ($cat.Name -eq "UninstallEntries") {
                    $displayName = $key.GetValue("DisplayName")
                    $installLoc = $key.GetValue("InstallLocation") ?? $key.GetValue("UninstallString")
                    if ($displayName -and $installLoc -and -not (Test-Path ($installLoc -replace '"',''))) {
                        $issue = "Árva telepítés: $displayName (hiányzó: $installLoc)"
                    }
                }
                elseif ($cat.Name -eq "Fonts" -and $valueData -and -not (Test-Path "$env:SystemRoot\Fonts\$valueData")) {
                    $issue = "Hiányzó font: $valueData"
                }
                elseif ($cat.Name -eq "StartupPrograms" -and $valueData) {
                    $exePath = ($valueData -split ' ')[0] -replace '"',''
                    if (-not (Test-Path $exePath)) { $issue = "Hiányzó startup exe: $exePath" }
                }
                elseif ($cat.Name -eq "ContextMenu_ShellEx" -and $valueData) {
                    # egyszerű CLSID ellenőrzés
                    if (-not (Test-Path "Registry::HKCR\CLSID\$valueData")) { $issue = "Árva Shell Extension: $valueData" }
                }
                
                if ($issue) {
                    $AllIssues += [PSCustomObject]@{
                        Category     = $cat.Name
                        Description  = $cat.Desc
                        Path         = $key.PSPath
                        Issue        = $issue
                        SafeToRemove = $true
                        ValueData    = $valueData
                    }
                    $IssuesInCat++
                }
            }
        }
    }
    $Stats[$cat.Name] = $IssuesInCat
    Write-Host "   → $($IssuesInCat) probléma" -ForegroundColor Gray
}

# === ÖSSZEFOGLALÓ + JSON ===
$TotalIssues = ($AllIssues | Measure-Object).Count
$Summary = "SCAN KÉSZ!`nÖsszes talált probléma: $TotalIssues db`n"
$Stats.GetEnumerator() | ForEach-Object { $Summary += "   $($_.Key): $($_.Value) db`n" }

Write-Host "`n$Summary" -ForegroundColor Green
$AllIssues | ConvertTo-Json -Depth 10 | Out-File -FilePath $JsonFile -Encoding UTF8

Write-Host "✅ ScanResults.json elkészült → $JsonFile" -ForegroundColor Green
Write-Host "Log: $LogFile" -ForegroundColor Gray
