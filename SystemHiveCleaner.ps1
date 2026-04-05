# ================================================
# SystemHive Optimizer - SCANNER modul (kompatibilis v0.5)
# Verzio: 0.5 - 2026.04.05
# Kompatibilis: Windows PowerShell 5.1 (Win7/10/11)
# ================================================

# === AUTO ADMIN ELEVATION ===
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Rendszergazdai jogok szuksegesek - ujrainditas admin modban..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$LogFile = "$env:TEMP\SystemHiveScanner_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$JsonFile = "$env:TEMP\ScanResults.json"

Write-Host "SystemHive Optimizer - SCANNER inditasa (melyitett scan)..." -ForegroundColor Green

# === BACKUP ===
reg export HKLM "$env:TEMP\Backup_HKLM.reg" /y | Out-Null
reg export HKCU "$env:TEMP\Backup_HKCU.reg" /y | Out-Null
Write-Host "Registry backup kesz (HKLM + HKCU)" -ForegroundColor Yellow

# === MELYITETT KATEGORIAK ===
$Categories = @(
    @{Name="ActiveX_COM_CLSID"; Desc="Arva ActiveX/COM/CLSID/TypeLib"; Paths=@("HKCR\CLSID","HKCR\TypeLib","HKLM\SOFTWARE\Classes","HKLM\SOFTWARE\Wow6432Node\Classes")}
    @{Name="FileAssociations"; Desc="Hibas fajltipus-asszociaciok"; Paths=@("HKCR\.","HKCR\*\shell","HKLM\SOFTWARE\Classes")}
    @{Name="UninstallEntries"; Desc="Arva telepitesi bejegyzesek (hianyzo fajl/mappa)"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall","HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall","HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")}
    @{Name="Fonts"; Desc="Hianyzo font fajlok"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts","HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts")}
    @{Name="SharedDLLs"; Desc="Arva Shared DLL bejegyzesek"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\SharedDLLs","HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\SharedDLLs")}
    @{Name="History_MRU"; Desc="Elavult History / MRU / RecentDocs"; Paths=@("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs","HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32","HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU")}
    @{Name="StartupPrograms"; Desc="Startup bejegyzesek hianyzo exe-re"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run","HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce","HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run","HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce")}
    @{Name="ContextMenu_ShellEx"; Desc="Arva Context Menu / Shell Extension handler-ek"; Paths=@("HKCR\*\shellex\ContextMenuHandlers","HKCR\Directory\shellex\ContextMenuHandlers","HKCR\Folder\shellex\ContextMenuHandlers")}
)

$AllIssues = @()
$Stats = @{}

foreach ($cat in $Categories) {
    $IssuesInCat = 0
    Write-Host "Scanning $($cat.Name) ..." -ForegroundColor White
    
    foreach ($path in $cat.Paths) {
        if (Test-Path "Registry::$path") {
            $keys = Get-ChildItem "Registry::$path" -Recurse -ErrorAction SilentlyContinue -Depth 4
            
            foreach ($key in $keys) {
                $issue = $null
                $valueData = $key.GetValue("")
                
                if ($cat.Name -eq "SharedDLLs" -and $valueData -and -not (Test-Path $valueData)) {
                    $issue = "Hianyzo DLL: $valueData"
                }
                elseif ($cat.Name -eq "UninstallEntries") {
                    $displayName = $key.GetValue("DisplayName")
                    $installLoc = $key.GetValue("InstallLocation")
                    if (-not $installLoc) { $installLoc = $key.GetValue("UninstallString") }
                    if ($displayName -and $installLoc) {
                        $cleanPath = ($installLoc -replace '"','' -replace '%SystemRoot%', $env:SystemRoot -replace '%ProgramFiles%', $env:ProgramFiles)
                        if (-not (Test-Path $cleanPath)) {
                            $issue = "Arva telepites: $displayName (hianyzo: $installLoc)"
                        }
                    }
                }
                elseif ($cat.Name -eq "Fonts" -and $valueData -and -not (Test-Path "$env:SystemRoot\Fonts\$valueData")) {
                    $issue = "Hianyzo font: $valueData"
                }
                elseif ($cat.Name -eq "StartupPrograms" -and $valueData) {
                    $exePath = ($valueData -split ' ')[0] -replace '"',''
                    if (-not (Test-Path $exePath)) { 
                        $issue = "Hianyzo startup exe: $exePath" 
                    }
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
    Write-Host "   -> $($IssuesInCat) problema" -ForegroundColor Gray
}

# === OSSZEFOGLALO + JSON EXPORT ===
$TotalIssues = ($AllIssues | Measure-Object).Count
$Summary = "SCAN KESZ!`nOsszes talalt problema: $TotalIssues db`n"
$Stats.GetEnumerator() | ForEach-Object { $Summary += "   $($_.Key): $($_.Value) db`n" }

Write-Host "`n$Summary" -ForegroundColor Green
$AllIssues | ConvertTo-Json -Depth 10 | Out-File -FilePath $JsonFile -Encoding UTF8

Write-Host "ScanResults.json elkeszult -> $JsonFile" -ForegroundColor Green
Write-Host "Log: $LogFile" -ForegroundColor Gray
