$ErrorActionPreference = "Stop"

# Percorsi agli strumenti già presenti sul tuo PC
$env:JAVA_HOME = "$env:USERPROFILE\jdk-17"
$env:ANDROID_HOME = "$env:USERPROFILE\Android\Sdk"
$env:PATH = "$env:USERPROFILE\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:PATH"

Write-Host "=== Compilazione APK Release di Preluded ==="
Set-Location "c:\Users\emiba\web-music"
if (Test-Path "build\app\outputs\flutter-apk\app-release.apk") {
    Remove-Item "build\app\outputs\flutter-apk\app-release.apk" -Force
}

flutter pub get
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "flutter build failed with exit code $LASTEXITCODE"
    exit 1
}

$builtApk = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $builtApk) {
    Copy-Item $builtApk "preluded.apk" -Force
    $sizeMb = [math]::Round(((Get-Item "preluded.apk").Length / 1MB), 2)
    Write-Host "=== APK GENERATO CON SUCCESSO: preluded.apk ($sizeMb MB) ===" -ForegroundColor Green

    try {
        $devs = & adb devices | Out-String
        if ($devs -match "`tdevice") {
            Write-Host "=== Dispositivo Android collegato trovato! Installazione automatica via ADB... ===" -ForegroundColor Cyan
            & adb -s RF8RC03HE4P install -r preluded.apk
            Write-Host "=== Avvio dell'app su Android... ===" -ForegroundColor Cyan
            & adb -s RF8RC03HE4P shell am start -n com.preluded.music/.MainActivity
            Write-Host "=== APPLICAZIONE PRONTA E ATTIVA SUL TELEFONO ===" -ForegroundColor Green
        } else {
            Write-Host "Nessun dispositivo rilevato come 'device' via adb devices." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Avviso durante operazione ADB: $_" -ForegroundColor Yellow
    }
} else {
    Write-Error "File APK non trovato in $builtApk"
}


