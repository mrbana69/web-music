param (
    [switch]$Run
)

$ErrorActionPreference = "Stop"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "       Compilazione Preluded Music per Windows        " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# 1. Verifica Modalità Sviluppatore (Symlink)
$devMode = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
if (-not $devMode -or $devMode.AllowDevelopmentWithoutDevLicense -ne 1) {
    Write-Host "`n[AVVISO] La Modalità Sviluppatore di Windows potrebbe non essere attiva." -ForegroundColor Yellow
    Write-Host "Flutter richiede i symlink abilitati per i plugin Windows." -ForegroundColor Yellow
    Write-Host "Se la compilazione fallisce sui symlink, apri le impostazioni e attivala:" -ForegroundColor Yellow
    Write-Host "   start ms-settings:developers`n" -ForegroundColor Yellow
}

# 2. Verifica Visual Studio C++ Tools
$hasCl = Get-Command "cl.exe" -ErrorAction SilentlyContinue
$hasCmake = Get-Command "cmake.exe" -ErrorAction SilentlyContinue
if (-not $hasCl -and -not $hasCmake) {
    Write-Host "[INFO] Strumenti C++ di Visual Studio non rilevati nel PATH." -ForegroundColor Yellow
    Write-Host "Se non hai installato Visual Studio con il carico di lavoro 'Sviluppo di applicazioni desktop con C++':" -ForegroundColor Yellow
    Write-Host "Puoi installarlo rapidamente con:" -ForegroundColor Yellow
    Write-Host "   winget install Microsoft.VisualStudio.2022.BuildTools --override ""--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended""" -ForegroundColor Cyan
    Write-Host "`nIn alternativa, il workflow GitHub Actions compila automaticamente il file .exe sul cloud!`n" -ForegroundColor Green
}

# 3. Abilita Windows Desktop in Flutter
Write-Host "Configurazione Flutter Windows Desktop..." -ForegroundColor Cyan
flutter config --enable-windows-desktop

# 4. Scarica le dipendenze
Write-Host "Download dipendenze..." -ForegroundColor Cyan
flutter pub get

# 5. Compilazione Release
Write-Host "Compilazione Windows in corso..." -ForegroundColor Cyan
flutter build windows --release

if ($LASTEXITCODE -eq 0) {
    $releaseFolder = "build\windows\x64\runner\Release"
    if (Test-Path "$releaseFolder\preluded_music.exe") {
        Write-Host "`n=== COMPILAZIONE COMPLETATA CON SUCCESSO! ===" -ForegroundColor Green
        Write-Host "Eseguibile generato in: $releaseFolder\preluded_music.exe" -ForegroundColor Green

        # Crea archivio ZIP
        Compress-Archive -Path "$releaseFolder\*" -DestinationPath "Preluded-Windows-Release.zip" -Force
        $zipSize = [math]::Round(((Get-Item "Preluded-Windows-Release.zip").Length / 1MB), 2)
        Write-Host "Archivio zip standalone: Preluded-Windows-Release.zip ($zipSize MB)" -ForegroundColor Green

        if ($Run) {
            Write-Host "Avvio applicazione in corso..." -ForegroundColor Cyan
            Start-Process "$releaseFolder\preluded_music.exe"
        }
    }
} else {
    Write-Error "Compilazione fallita con exit code $LASTEXITCODE"
}
