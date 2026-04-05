# ================================================
# SystemHive Optimizer - SCANNER modul (v0.8)
# Progress indikator + Tmp mappa
# ================================================

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Rendszergazdai jogok szuksegesek - ujrainditas admin modban..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Saját Tmp mappa a projekt gyokerében
$TmpDir = Join-Path $PSScriptRoot "Tmp"
if (-not (Test-Path $TmpDir)) { New-Item -Path $TmpDir -ItemType Directory -Force | Out-Null }

$JsonFile = Join-Path $TmpDir "ScanResults.json"
$BackupHKLM = Join-Path $TmpDir "Backup_HKLM.reg"
$BackupHKCU = Join-Path $TmpDir "Backup_HKCU.reg"

Write-Host "SystemHive Optimizer - SCANNER inditasa (alapos verzio)..." -ForegroundColor Green

# Backup a Tmp mappaba
reg export HKLM $BackupHKLM /y | Out-Null
reg export HKCU $BackupHKCU /y | Out-Null
Write-Host "Registry backup kesz -> $TmpDir mappaba" -ForegroundColor Yellow

$Categories = @(
    @{Name="ActiveX_COM_CLSID"; Desc="Arva ActiveX/COM/CLSID/TypeLib"; Paths=@("HKCR\CLSID","HKCR\TypeLib","HKLM\SOFTWARE\Classes","HKLM\SOFTWARE\Wow6432Node\Classes")}
    @{Name="FileAssociations"; Desc="Hibas fajltipus-asszociaciok"; Paths=@("HKCR\.","HKCR\*\shell","HKLM\SOFTWARE\Classes")}
    @{Name="UninstallEntries"; Desc="Arva telepitesi bejegyzesek"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall","HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall","HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")}
    @{Name="Fonts"; Desc="Hianyzo font fajlok"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts","HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts")}
    @{Name="SharedDLLs"; Desc="Arva Shared DLL bejegyzesek"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\SharedDLLs","HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\SharedDLLs")}
    @{Name="History_MRU"; Desc="Elavult History / MRU"; Paths=@("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs","HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32","HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU")}
    @{Name="StartupPrograms"; Desc="Hianyzo startup exe"; Paths=@("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run","HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce","HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run","HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce")}
    @{Name="ContextMenu_ShellEx"; Desc="Arva Context Menu / Shell Extension"; Paths=@("HKCR\*\shellex\ContextMenuHandlers","HKCR\Directory\shellex\ContextMenuHandlers","HKCR\Folder\shellex\ContextMenuHandlers")}
)

$AllIssues = @()

foreach ($cat in $Categories) {
    $IssuesInCat = 0
    Write-Host "Scanning $($cat.Name) ..." -NoNewline -ForegroundColor White
    
    $Progress = 0
    foreach ($path in $cat.Paths) {
        if (Test-Path "Registry::$path") {
            $keys = Get-ChildItem "Registry::$path" -Recurse -ErrorAction SilentlyContinue -Depth 5
            
            foreach ($key in $keys) {
                $issue = $null
                $valueData = $key.GetValue("")
                
                # Ugyanazok az ellenorzesek mint korabban
                if ($cat.Name -eq "SharedDLLs" -and $valueData -and -not (Test-Path $valueData)) {
                    $issue = "Hianyzo DLL: $valueData"
                }
                elseif ($cat.Name -eq "UninstallEntries") {
                    $displayName = $key.GetValue("DisplayName")
                    $installLoc = $key.GetValue("InstallLocation")
                    if (-not $installLoc) { $installLoc = $key.GetValue("UninstallString") }
                    if ($displayName -and $installLoc) {
                        $cleanPath = ($installLoc -replace '"','' -replace '%SystemRoot%', $env:SystemRoot)
                        if (-not (Test-Path $cleanPath)) {
                            $issue = "Arva telepites: $displayName"
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
                        Category = $cat.Name
                        Issue    = $issue
                        Path     = $key.PSPath
                    }
                    $IssuesInCat++
                }
                
                # Progress pontok ugyanazon a soron (10 pont, majd torles)
                $Progress++
                if ($Progress % 800 -eq 0) {
                    Write-Host "." -NoNewline
                    if ($Progress % 8000 -eq 0) {
                        Write-Host "`b`b`b`b`b`b`b`b        `b`b`b`b`b`b`b`b" -NoNewline   # torles
                    }
                }
            }
        }
    }
    Write-Host " -> $($IssuesInCat) problema" -ForegroundColor Gray
}

$Total = $AllIssues.Count
Write-Host "`nSCAN KESZ! Osszes talalt problema: $Total db" -ForegroundColor Green
$AllIssues | ConvertTo-Json -Depth 8 | Out-File $JsonFile -Encoding UTF8
Write-Host "Eredmeny mentve: $JsonFile" -ForegroundColor Green
Write-Host "Backup fajlok: $TmpDir mappaban" -ForegroundColor Yellow
