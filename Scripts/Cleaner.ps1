# ================================================
# SystemHive Optimizer - CLEANER
# Verzio: 0.5 - 2026.05
# ================================================

param([string]$JsonPath = "")

# === ADMIN ELEVATION ===
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Rendszergazdai jogok szuksegesek. Ujrainditas admin modban..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -JsonPath `"$JsonPath`"" -Verb RunAs
    exit
}

# === DUAL PATH ===
$ProjectName = "SystemHive-Optimizer"
$InstalledPath = "C:\Windows\Scripts\$ProjectName"
$LocalRoot = Split-Path -Parent $PSScriptRoot
$Root = if (Test-Path $InstalledPath) { $InstalledPath } else { $LocalRoot }

$TempDir = Join-Path $Root "Temp"
$LogDir  = Join-Path $Root "Logs"
$BackupDir = Join-Path $Root "Backup\RescueCenter_$(Get-Date -Format 'yyyyMMdd-HHmmss')"

foreach ($dir in @($LogDir, $BackupDir)) {
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
}

$LogFile = Join-Path $LogDir "Cleaner_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log { 
    param($msg) 
    "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) | $msg" | Out-File $LogFile -Append -Encoding UTF8 
}

if (-not $JsonPath) { $JsonPath = Join-Path $TempDir "ScanResults.json" }

if (-not (Test-Path $JsonPath)) {
    Write-Host "Nincs talalhato ScanResults.json!" -ForegroundColor Red
    exit
}

$Issues = Get-Content $JsonPath -Raw | ConvertFrom-Json
$ToRemove = $Issues | Where-Object { $_.SafeToRemove -eq $true }

Write-Host "Cleaner inditasa - $($ToRemove.Count) torlendo elem..." -ForegroundColor Yellow
Write-Log "Cleaner elindult - $($ToRemove.Count) elem"

foreach ($item in $ToRemove) {
    try {
        $CleanPath = $item.Path -replace '.*Registry::', ''
        
        # Undo backup
        $BackupFile = Join-Path $BackupDir "$($item.Category)_$(Get-Date -Format 'HHmmss').reg"
        reg export "$CleanPath" $BackupFile /y | Out-Null
        
        # .NET alapu torles (mélyebb)
        $hive = if ($CleanPath.StartsWith("HKEY_LOCAL_MACHINE")) { [Microsoft.Win32.Registry]::LocalMachine }
                elseif ($CleanPath.StartsWith("HKEY_CURRENT_USER")) { [Microsoft.Win32.Registry]::CurrentUser }
                else { [Microsoft.Win32.Registry]::ClassesRoot }
        
        $subPath = $CleanPath.Substring($CleanPath.IndexOf('\') + 1)
        $key = $hive.OpenSubKey($subPath, $true)
        
        if ($key) {
            $key.DeleteSubKeyTree("")
            $key.Close()
            Write-Log "TOROLVE: $($item.Path) | $($item.Issue)"
            Write-Host "  TOROLVE -> $($item.Issue)" -ForegroundColor Green
        }
    }
    catch {
        Write-Log "HIBA: $($item.Path) - $($_.Exception.Message)"
        Write-Host "  HIBA: $($item.Issue)" -ForegroundColor Red
    }
}

Write-Host "`nCleaner kesz. Rescue Center: $BackupDir" -ForegroundColor Green
Write-Log "Cleaner befejezve"
