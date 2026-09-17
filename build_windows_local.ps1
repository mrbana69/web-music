param (
    [switch]$Run
)

$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

# Assicura che Flutter sia nel PATH della sessione corrente
$flutterCandidates = @(
    "$env:USERPROFILE\flutter\bin",
    "C:\flutter\bin",
    "C:\src\flutter\bin"
)
foreach ($dir in $flutterCandidates) {
    if (Test-Path "$dir\flutter.bat") {
        if ($env:PATH -notlike "*$dir*") {
            $env:PATH = "$dir;$env:PATH"
        }
        break
    }
}

$hasFlutter = Get-Command "flutter" -ErrorAction SilentlyContinue
if (-not $hasFlutter) {
    Write-Host "`n[ERRORE PREREQUISITO] Flutter SDK non trovato nel PATH o nei percorsi standard." -ForegroundColor Red
    Write-Host "Verifica che Flutter sia installato (ad es. in $env:USERPROFILE\flutter\bin) e aggiunto al PATH." -ForegroundColor Yellow
    exit 1
}

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
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsFound = $false
if (Test-Path $vswhere) {
    $installPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($installPath) { $vsFound = $true }
}

$hasCl = Get-Command "cl.exe" -ErrorAction SilentlyContinue
if (-not $vsFound -and -not $hasCl) {
    Write-Host "`n[ERRORE PREREQUISITO] Visual Studio C++ Toolchain non trovata." -ForegroundColor Red
    Write-Host "Flutter richiede il carico di lavoro 'Sviluppo di applicazioni desktop con C++' per creare l'app Windows." -ForegroundColor Yellow
    Write-Host "`n--> COME RISOLVERE (SCEGLI UNA DELLE 2 STRADE):" -ForegroundColor Cyan
    Write-Host "`nOPZIONE A (Nessuna installazione sul tuo PC - Piu veloce):" -ForegroundColor Green
    Write-Host "Scarica direttamente l'eseguibile .exe compilato da GitHub Actions:" -ForegroundColor White
    Write-Host "https://github.com/mrbana69/web-music/actions`n" -ForegroundColor Cyan
    Write-Host "OPZIONE B (Compilazione in locale sul tuo PC):" -ForegroundColor Green
    Write-Host "1. Apri PowerShell COME AMMINISTRATORE (tasto destro su Start -> Terminale/PowerShell come Amministratore)" -ForegroundColor White
    Write-Host "2. Incolla ed esegui questo comando:" -ForegroundColor White
    Write-Host "   winget install Microsoft.VisualStudio.2022.BuildTools --override ""--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended""" -ForegroundColor Yellow
    Write-Host "3. Riavvia questo script: .\build_windows_local.ps1`n" -ForegroundColor White
    exit 1
}

# 3. Abilita Windows Desktop in Flutter
Write-Host "Configurazione Flutter Windows Desktop..." -ForegroundColor Cyan
flutter config --enable-windows-desktop

# 4. Scarica le dipendenze
Write-Host "Download dipendenze..." -ForegroundColor Cyan
flutter pub get

# 5. Compilazione Release
Write-Host "Verifica processi attivi..." -ForegroundColor Cyan
Get-Process "preluded_music" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

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

