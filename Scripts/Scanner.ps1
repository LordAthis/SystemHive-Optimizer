# ================================================
# SystemHive Optimizer - SCANNER
# Verzio: 0.5 - 2026.05
# ================================================

# === ADMIN ELEVATION ===
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Rendszergazdai jogok szuksegesek. Ujrainditas admin modban..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
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

$JsonFile = Join-Path $TempDir "ScanResults.json"

Write-Host "SystemHive Optimizer - SCANNER (0.5) inditasa..." -ForegroundColor Green
Write-Host "Munkakonyvtar: $Root" -ForegroundColor Gray

# Registry backup
reg export HKLM (Join-Path $TempDir "Backup_HKLM.reg") /y | Out-Null
reg export HKCU (Join-Path $TempDir "Backup_HKCU.reg") /y | Out-Null
Write-Host "Registry backup kesz." -ForegroundColor Yellow

# .NET alapu registry scan
$AllIssues = @()

$ScanCategories = @(
    @{Name="SharedDLLs";       Paths=@("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\SharedDLLs", "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\SharedDLLs")}
    @{Name="Uninstall";        Paths=@("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")}
    @{Name="CLSID_TypeLib";    Paths=@("HKCR:\CLSID", "HKCR:\TypeLib")}
    @{Name="Fonts";            Paths=@("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts")}
    @{Name="Startup";          Paths=@("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce")}
    @{Name="ContextMenu";      Paths=@("HKCR:\*\shellex\ContextMenuHandlers", "HKCR:\Directory\shellex")}
)

foreach ($cat in $ScanCategories) {
    $Count = 0
    Write-Host "Scanning $($cat.Name) ..." -NoNewline
    
    foreach ($regPath in $cat.Paths) {
        if (Test-Path $regPath) {
            $items = Get-ChildItem $regPath -Recurse -ErrorAction SilentlyContinue -Depth 4
            
            foreach ($item in $items) {
                $issue = $null
                try {
                    # .NET RegistryKey objektum
                    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($item.PSPath.Replace("Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\",""), $false)
                    if (-not $key) { $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($item.PSPath.Replace("Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\",""), $false) }
                    
                    if ($key) {
                        if ($cat.Name -eq "SharedDLLs") {
                            $value = $key.GetValue($null)
                            if ($value -and -not (Test-Path $value)) {
                                $issue = "Hianyzo DLL: $value"
                            }
                        }
                        elseif ($cat.Name -eq "Uninstall") {
                            $dispName = $key.GetValue("DisplayName")
                            $uninstStr = $key.GetValue("UninstallString")
                            if ($dispName -and $uninstStr) {
                                $exe = ($uninstStr -replace '"','' -split ' ')[0]
                                if (-not (Test-Path $exe)) {
                                    $issue = "Arva uninstall: $dispName"
                                }
                            }
                        }
                        # További kategóriák finomhangolása...
                    }
                    if ($key) { $key.Close() }
                }
                catch {}
                
                if ($issue) {
                    $AllIssues += [PSCustomObject]@{
                        Category     = $cat.Name
                        Issue        = $issue
                        Path         = $item.PSPath
                        SafeToRemove = $true
                    }
                    $Count++
                }
            }
        }
    }
    Write-Host " -> $Count talalat" -ForegroundColor Gray
}

$AllIssues | ConvertTo-Json -Depth 10 | Out-File $JsonFile -Encoding UTF8
Write-Host "`nSCAN KESZ! Osszes talalat: $($AllIssues.Count) db" -ForegroundColor Green
Write-Host "Eredmeny mentve: $JsonFile" -ForegroundColor Green
