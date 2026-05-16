# ================================================
# SystemHive Optimizer - CLEANER (v0.5)
# ================================================

param([string]$JsonPath = "")

# Admin elevation (ugyanaz mint a launcherben)...

$TempDir = Join-Path $PSScriptRoot ".." "Temp"
$LogDir  = Join-Path $PSScriptRoot ".." "Logs"
$RescueDir = Join-Path $PSScriptRoot ".." "Backup\RescueCenter_$(Get-Date -Format 'yyyyMMdd-HHmmss')"

New-Item -Path $RescueDir -ItemType Directory -Force | Out-Null

$LogFile = Join-Path $LogDir "Cleaner_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log { param($msg); "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) - $msg" | Out-File $LogFile -Append }

Write-Log "Cleaner elindult"

if (-not $JsonPath -or -not (Test-Path $JsonPath)) {
    $JsonPath = Join-Path $TempDir "ScanResults.json"
}

if (-not (Test-Path $JsonPath)) {
    Write-Host "Nincs ScanResults.json!" -ForegroundColor Red
    exit
}

$Issues = Get-Content $JsonPath -Raw | ConvertFrom-Json

$ToRemove = $Issues | Where-Object { $_.SafeToRemove -eq $true }

Write-Host "Törlendő elemek: $($ToRemove.Count) db" -ForegroundColor Yellow

foreach ($item in $ToRemove) {
    try {
        $Path = $item.Path -replace 'Microsoft.PowerShell.Core\\Registry::', ''
        
        # Backup (undo lehetőség)
        reg export "$Path" "$RescueDir\$($item.Category)_$((Get-Date).Ticks).reg" /y | Out-Null
        
        Remove-Item -Path "Registry::$Path" -Recurse -Force -ErrorAction Stop
        Write-Host "TÖRÖLVE: $($item.Issue)" -ForegroundColor Green
        Write-Log "TÖRÖLVE: $($item.Path) | $($item.Issue)"
    }
    catch {
        Write-Host "HIBA: $($item.Path)" -ForegroundColor Red
        Write-Log "HIBA: $($item.Path) - $($_.Exception.Message)"
    }
}

Write-Host "`nCleaner kész. RescueCenter: $RescueDir" -ForegroundColor Cyan
Write-Log "Cleaner befejezve"
