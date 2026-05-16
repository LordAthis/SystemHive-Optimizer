# SystemHive-Optimizer
SystemHive Optimizer: Reristry Cleaning, and Defrag, File Cleaning, and defrag, end more...

**Windows Registry tisztító és optimalizáló eszköz** – precíz, biztonságos és visszavonható módon.
---------------------------------------------
FIGYELEM! FEJLESZTÉS ALATT, KIZÁRÓLAG SAJÁT FELELŐSSÉGRE HASZNÁLD!
-------------------------------------------

Verzió: **0.5** (2026.05)



---

## Funkciók

- Árva registry bejegyzések keresése (Uninstall, SharedDLLs, CLSID, ContextMenu, Startup, stb.)
- Biztonságos takarítás **undo** lehetőséggel (Rescue Center)
- Teljes registry backup indítás előtt
- Automatikus telepítés `C:\Windows\Scripts\SystemHive-Optimizer` mappába (újraindítás után is működik)
- Laptop akkumulátor + tápellátás ellenőrzés
- Altatás kikapcsolása futás közben
- Részletes logolás és JSON alapú eredmények
- Beépített Bloat Simulator teszteléshez


---
## Könyvtárstruktúra

SystemHive-Optimizer/
   ├── Launcher.ps1
   ├── Scripts/
   │   ├── Scanner.ps1
   │   ├── Cleaner.ps1
   │   └── BloatSimulator.ps1
   ├── Data/
   │   ├── whitelist.json
   │   ├── blacklist_patterns.json
   │   └── system_profiles/
   ├── Temp/
   ├── Logs/
   ├── Backup/
   ├── README.md
   └── .gitignore


---

## Használat

### Ajánlott módszer

1. Töltsd le a repository-t
2. **Jobb klikk** a `Launcher.ps1` fájlon → **"PowerShell-lel futtatás"** (vagy futtasd rendszergazdaként)

A Launcher automatikusan elvégzi a szükséges lépéseket:
- Ellenőrzi a jogosultságokat
- Létrehozza a szükséges mappákat
- Telepíti a projektet a `C:\Windows\Scripts\` mappába
- Ellenőrzi a tápellátást
- Sorrendben futtatja a Scanner → Cleaner folyamatot

### Parancssori opciók

```powershell
.\Launcher.ps1 -SimulateBloat     # Bloat szimuláció futtatása teszteléshez
.\Launcher.ps1 -AutoClean         # Automatikus takarítás (confirmation nélkül)
```

## Fájlok rövid leírása


| Fájl                  | Funkció |
|-----------------------|--------|
| Launcher.ps1          | Fő indító, admin jog, ellenőrzések, sorrend, telepítés, folyamatirányítás |
| Scanner.ps1           | Problémák felderítése, JSON export |
| Cleaner.ps1           | Biztonságos takarítás + Rescue Center |
| BloatSimulator.ps1    | Teszteléshez registry ""szennyezése"" |


## Biztonság

- Indítás előtt mindig teljes registry backupot készít
- Csak SafeToRemove elemek törlése (SafeToRemove = true)
- Minden törlés előtt .reg mentés (undo-hoz)
- Whitelist védelem (A Whitelist rendszer védi a kritikus kulcsokat!)

> Figyelem:Első használat előtt ajánlott rendszer-visszaállítási pont létrehozása!


## Fejlesztés alatt

- A Whitelist / Blacklist integráció finomhangolása
- További rendszerprofilok (a /Data/system_profiles/ mappában)
- GUI Launcher (Az RTS keretrendszer - Külön REPÓ! - Később kerül fejlesztésre!)
- Registry compact / defrag funkció



## Közreműködés:
Pull requesteket, javaslatokat szívesen fogadunk.


