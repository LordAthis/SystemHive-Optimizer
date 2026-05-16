# Launcher.ps1
param([switch]$SimulateBloat)

$ScriptDir = "$PSScriptRoot\Scripts"

Write-Host "=== SystemHive Optimizer Launcher ===" -ForegroundColor Cyan

if ($SimulateBloat) {
    & "$ScriptDir\SystemHiveBloatSimulator.ps1" -Cycles 30
}

& "$ScriptDir\SystemHiveScanner.ps1"
# Itt lehet pause + JSON review

$Choice = Read-Host "Futtassuk a Cleaner-t? (Y/N)"
if ($Choice -eq 'Y' -or $Choice -eq 'y') {
    & "$ScriptDir\SystemHiveCleaner.ps1"
}

Write-Host "Kész." -ForegroundColor Green
