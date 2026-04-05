# === RegHiveBloatSimulator.ps1 ===
param([int]$Cycles = 50)  # hány „éves” telepítés/törlés szimuláljunk

Write-Host "🚀 Registry bloat szimuláció indítása ($Cycles ciklus)..."

for ($i = 1; $i -le $Cycles; $i++) {
    # 1. Telepítünk 10-15 random programot (choco vagy winget)
    # 2. Létrehozunk sok dummy kulcsot (HKEY_CURRENT_USER\Software\FakeApp$i)
    # 3. Töröljük a programot (de hagyunk maradékot)
    # 4. Random fájlokat + registry entry-ket szemetelünk
    # 5. Sleep 2-5 sec (valósághű)
}

Write-Host "✅ Bloat kész! Most futtasd a RegHive Compact-ot és mérd a különbséget."
