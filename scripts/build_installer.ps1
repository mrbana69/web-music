# build_installer.ps1 - Automated Windows Release & Installer Builder for Preluded Music
param(
    [switch]$SkipFlutterBuild,
    [switch]$AutoInstallInnoSetup
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Preluded Music - Windows Installer Build" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$projectRoot = Resolve-Path "$PSScriptRoot\.."
Set-Location $projectRoot

# Step 1: Flutter Build Windows Release
$releaseExe = "$projectRoot\build\windows\x64\runner\Release\preluded_music.exe"

if (-not $SkipFlutterBuild -or -not (Test-Path $releaseExe)) {
    Write-Host "`n[1/3] Compilazione release Windows (Flutter)..." -ForegroundColor Yellow
    Get-Process preluded_music -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Compilazione Flutter Windows fallita!"
        exit 1
    }
    Write-Host "[1/3] Compilazione Flutter completata con successo!" -ForegroundColor Green
} else {
    Write-Host "`n[1/3] Skip compilazione Flutter (--SkipFlutterBuild specificato)" -ForegroundColor Gray
}

# Step 2: Trova o installa Inno Setup
Write-Host "`n[2/3] Ricerca compilatore Inno Setup (ISCC.exe)..." -ForegroundColor Yellow

$isccCandidates = @(
    "ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
    "${env:LOCALAPPDATA}\Programs\Inno Setup 6\ISCC.exe"
)

$isccPath = $null
foreach ($candidate in $isccCandidates) {
    if (Get-Command $candidate -ErrorAction SilentlyContinue) {
        $isccPath = (Get-Command $candidate).Source
        break
    } elseif (Test-Path $candidate) {
        $isccPath = $candidate
        break
    }
}

if (-not $isccPath) {
    Write-Host "Inno Setup non rilevato nel sistema." -ForegroundColor Yellow
    
    if ($AutoInstallInnoSetup) {
        Write-Host "Installazione automatica di Inno Setup tramite winget..." -ForegroundColor Cyan
        winget install JRSoftware.InnoSetup --silent --accept-package-agreements --accept-source-agreements
        # Ricontrolla i path dopo l'installazione
        foreach ($candidate in $isccCandidates) {
            if (Test-Path $candidate) {
                $isccPath = $candidate
                break
            }
        }
    }
    
    if (-not $isccPath) {
        Write-Host "`nPer compilare l'installer .exe e necessario Inno Setup (gratuito e open source)." -ForegroundColor Red
        Write-Host "Puoi installarlo aprendo PowerShell ed eseguendo:" -ForegroundColor White
        Write-Host "    winget install JRSoftware.InnoSetup" -ForegroundColor Green
        Write-Host "Oppure riscaricando questo script con il flag -AutoInstallInnoSetup:" -ForegroundColor White
        Write-Host "    .\scripts\build_installer.ps1 -AutoInstallInnoSetup" -ForegroundColor Green
        Write-Host "`nI file compilati dell'app sono comunque pronti in:" -ForegroundColor Gray
        Write-Host "    $projectRoot\build\windows\x64\runner\Release\" -ForegroundColor White
        exit 1
    }
}

Write-Host "Trovato Inno Setup: $isccPath" -ForegroundColor Green

# Step 3: Compila l'installer con Inno Setup
Write-Host "`n[3/3] Generazione installer PreludedMusic-Setup-x64.exe..." -ForegroundColor Yellow
$issScript = "$projectRoot\windows\installer\preluded_installer.iss"
$outputDir = "$projectRoot\build\installer"

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

& "$isccPath" "$issScript"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Compilazione dell'installer Inno Setup fallita!"
    exit 1
}

$setupExe = "$outputDir\PreludedMusic-Setup-x64.exe"
if (Test-Path $setupExe) {
    $sizeMb = [math]::Round(((Get-Item $setupExe).Length / 1MB), 2)
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host "  INSTALLER CREATO CON SUCCESSO!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "File: $setupExe" -ForegroundColor Cyan
    Write-Host "Dimensione: $sizeMb MB" -ForegroundColor White
    Write-Host "`nL'utente puo ora fare doppio clic su questo file per installare Preluded Music su Windows!" -ForegroundColor Yellow
} else {
    Write-Error "File di setup non trovato in $setupExe"
    exit 1
}

