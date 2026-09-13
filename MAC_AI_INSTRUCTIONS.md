# 🍎 ISTRUZIONI PER L'AI SU MAC (Preluded iOS)

Questo documento è destinato all'agente AI in esecuzione sul Mac dell'utente per compilare, testare, firmare ed eseguire l'applicazione **Preluded Music** su **iOS (iPhone e Simulatore)**.

---

## 📌 Panoramica del Progetto
- **Framework**: Flutter 3.x (Dart)
- **Target OS**: iOS 14.0+ (ottimizzato per iOS 17 / 18)
- **Motore Audio Nativo iOS**: `AVPlayer` tramite `just_audio` + `audio_service`
- **Proxy Locale Audio**: `LocalStreamProxy` su `http://127.0.0.1:42783` (evita l'errore HTTP 403 di YouTube gestendo Range headers e rate-bypass)
- **UI & Design**: Material 3 con Apple Frosted Glass (`GlassContainer` con `BackdropFilter` sigma 25), animazioni fluide e font **Syne** e **Inter**.

---

## 🚀 PASSO 1: Verifica del Branch
L'agente AI sul Mac deve assicurarsi di essere sul branch `ios` aggiornato:

```bash
git fetch origin
git checkout ios
git pull origin ios
```

Verifica che il working tree sia pulito:
```bash
git status
```

---

## 📦 PASSO 2: Installazione Dipendenze e CocoaPods
Esegui i seguenti comandi nella root del progetto:

```bash
# 1. Recupera le dipendenze Flutter/Dart
flutter pub get

# 2. Installa i Pod iOS nativi
cd ios
pod install
cd ..
```

> [!TIP]
> Se CocoaPods segnala conflitti di cache o versioni, esegui:
> ```bash
> cd ios
> pod deintegrate
> pod repo update
> pod install
> cd ..
> ```

---

## 📱 PASSO 3: Esecuzione su Simulatore o iPhone Fisico

### A. Esecuzione da riga di comando
1. Trova i dispositivi disponibili:
   ```bash
   flutter devices
   ```
2. Avvia l'app sul dispositivo scelto:
   ```bash
   flutter run -d <DEVICE_ID>
   ```

### B. Apertura in Xcode (Consigliato per iPhone fisico / Firma)
> [!IMPORTANT]
> Apri SEMPRE il file `.xcworkspace`, **MAI** il file `.xcodeproj` (altrimenti CocoaPods non viene collegato):

```bash
open ios/Runner.xcworkspace
```

---

## 🔑 PASSO 4: Firma del Progetto in Xcode (Code Signing)
Se installi l'app su un **iPhone fisico**, Xcode richiederà una firma:

1. In Xcode, seleziona il progetto principale **Runner** nella colonna di sinistra.
2. Vai nella scheda **Signing & Capabilities**.
3. Sotto **Team**, seleziona il tuo account Apple ID (anche un account Apple personale gratuito va benissimo).
4. Se Xcode segnala che il `Bundle Identifier` (`com.preluded.music`) è già registrato, cambialo in qualcosa di unico, ad esempio `com.tuonome.preluded`.
5. Verifica che sotto **Background Modes** siano spuntati:
   - `Audio, AirPlay, and Picture in Picture`
   - `Background fetch`
   - `Remote notifications`
   *(Questi sono già preconfigurati in `Info.plist`)*.

---

## 📦 PASSO 5: Generazione File `.ipa` (per AltStore / Sideloadly / TrollStore)
Se l'utente vuole installare l'app tramite sideloading senza passare da Xcode ogni volta, l'AI può generare il pacchetto `.ipa` non firmato:

```bash
# 1. Compila la versione Release per iOS
flutter build ios --release --no-codesign

# 2. Crea la struttura Payload e zippa in IPA
cd build/ios/iphoneos
mkdir -p Payload
cp -r Runner.app Payload/
zip -r -9 Preluded-iOS.ipa Payload
mv Preluded-iOS.ipa ../../../Preluded-iOS.ipa
cd ../../../

echo "✅ File IPA generato nella root: Preluded-iOS.ipa"
```

Questo file `.ipa` può essere inviato ad **AltStore**, **Sideloadly**, **LiveContainer** o **TrollStore** e installato immediatamente.

---

## 🛠️ Note Tecniche per l'AI
1. **Network Security & Proxy Locale**:
   In `ios/Runner/Info.plist`, la chiave `NSAllowsLocalNetworking` e `NSAllowsArbitraryLoads` sono già attive. Non rimuoverle: servono a far comunicare `AVPlayer` con il server `HttpServer.bind` su `127.0.0.1`.
2. **AudioSession**:
   In `ios/Runner/AppDelegate.swift`, l'istanza `AVAudioSession.sharedInstance().setCategory(.playback, ...)` è già attiva all'avvio. Garantisce l'integrazione con Dynamic Island, schermata di blocco e auricolari/AirPods.
3. **Login Google**:
   Su iOS il login utilizza nativamente `WKWebView` (tramite `webview_flutter_wkwebview`). L'estrazione cookie SAPISID avviene nello stesso identico modo di Android.
