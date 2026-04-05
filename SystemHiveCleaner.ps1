# ================================================
# SystemHive Optimizer - CLEANER modul (javító v0.1)
# Verzió: 0.3 - 2026.04.05
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

$JsonFile = "$env:TEMP\ScanResults.json"
$RescueFile = "$env:TEMP\RescueCenter_Clean_$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

if (-not (Test-Path $JsonFile)) {
    Write-Host "❌ Nincs ScanResults.json! Először futtasd a Scanner-t." -ForegroundColor Red
    pause
    exit
}

$Issues = Get-Content $JsonFile | ConvertFrom-Json
Write-Host "🛠️ SystemHive Optimizer - CLEANER indítása..." -ForegroundColor Green
Write-Host "Talált problémák száma: $($Issues.Count) db" -ForegroundColor Yellow

# === BACKUP MÉG EGYSZER ===
reg export HKLM "$env:TEMP\PreClean_HKLM.reg" /y | Out-Null
reg export HKCU "$env:TEMP\PreClean_HKCU.reg" /y | Out-Null

$Repaired = @()
$Choice = Read-Host "Mindent javítunk? (Y = igen, N = kategóriánként kérdez) [Y/N]"
$RepairAll = $Choice -eq "Y"

foreach ($item in $Issues) {
    if (-not $RepairAll) {
        $c = Read-Host "Javítjuk? $($item.Category) - $($item.Issue) (Y/N)"
        if ($c -ne "Y") { continue }
    }
    
    try {
        # Biztonságos törlés
        if ($item.Path -like "*\Values*") {
            Remove-ItemProperty -Path $item.Path -Name $item.ValueData -ErrorAction Stop
        } else {
            Remove-Item -Path $item.Path -Recurse -ErrorAction Stop
        }
        $Repaired += $item
        Write-Host "✅ Javítva: $($item.Issue)" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Nem sikerült: $($item.Issue)" -ForegroundColor Red
    }
}

# === RESCUE CENTER LOG ===
$Repaired | ConvertTo-Json -Depth 10 | Out-File -FilePath $RescueFile -Encoding UTF8

Write-Host "`n✅ CLEANER KÉSZ! Javított elemek: $($Repaired.Count) db" -ForegroundColor Green
Write-Host "RescueCenter mentve: $RescueFile" -ForegroundColor Yellow
Write-Host "Visszaállításhoz használd a .reg backup fájlokat vagy System Restore-t." -ForegroundColor Cyan
pause
