$ErrorActionPreference = "Stop"

# Percorsi agli strumenti già presenti sul tuo PC
$env:JAVA_HOME = "$env:USERPROFILE\jdk-17"
$env:ANDROID_HOME = "$env:USERPROFILE\Android\Sdk"
$env:PATH = "$env:USERPROFILE\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:PATH"

Write-Host "=== Compilazione APK Release di Preluded ==="
Set-Location "c:\Users\emiba\web-music"

flutter pub get
flutter build apk --release

$builtApk = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $builtApk) {
    Copy-Item $builtApk "preluded.apk" -Force
    $sizeMb = [math]::Round(((Get-Item "preluded.apk").Length / 1MB), 2)
    Write-Host "=== APK GENERATO CON SUCCESSO: preluded.apk ($sizeMb MB) ===" -ForegroundColor Green
} else {
    Write-Error "File APK non trovato in $builtApk"
}

