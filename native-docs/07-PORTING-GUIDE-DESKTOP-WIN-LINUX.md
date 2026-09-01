# 💻 Preluded - Guida Implementazione Desktop (Windows & Linux)

Questa guida illustra le opzioni tecnologiche e i dettagli di integrazione per sviluppare l'app nativa **Windows** e **Linux** di Preluded.

---

## 🚀 1. Le Migliori Scelte Tecnologiche Desktop

| Tecnologia | Linguaggio | Piattaforme | Consumo RAM | Peso Binario | Pro |
|---|---|---|---|---|---|
| **Tauri (Consigliata)** | Rust + HTML/TS | Win, Linux, Mac | ~35 MB | ~8 MB | Riutilizza l'interfaccia esistente con performance native e zero overhead di Chromium. |
| **Flutter Desktop** | Dart / C++ | Win, Linux, Android | ~60 MB | ~20 MB | Unico codice per mobile e desktop, rendering grafico a 120fps con Skia/Impeller. |
| **WinUI 3 / .NET 8** | C# / XAML | Solo Windows | ~50 MB | ~30 MB | Massima integrazione con Windows 11 (Mica/Acrylic, controlli nativi). |

---

## 🪟 2. Integrazione con Windows

### A. System Media Transport Controls (SMTC)
Permette di visualizzare il brano in riproduzione nel popup del volume di Windows 11, nella barra delle applicazioni e di intercettare i tasti multimediali della tastiera (Play/Pause, Next, Prev):

#### Implementazione in C# (WinUI 3 / WPF):
```csharp
using Windows.Media;
using Windows.Media.Playback;
using Windows.Storage.Streams;

public class WindowsMediaManager {
    private MediaPlayer _player;
    private SystemMediaTransportControls _smtc;

    public void Initialize() {
        _player = new MediaPlayer();
        _smtc = _player.SystemMediaTransportControls;
        _smtc.IsPlayEnabled = true;
        _smtc.IsPauseEnabled = true;
        _smtc.IsNextEnabled = true;
        _smtc.IsPreviousEnabled = true;
        _smtc.ButtonPressed += Smtc_ButtonPressed;
    }

    public void UpdateMetadata(string title, string artist, string album, string coverUrl) {
        var updater = _smtc.DisplayUpdater;
        updater.Type = MediaPlaybackType.Music;
        updater.MusicProperties.Title = title;
        updater.MusicProperties.Artist = artist;
        updater.MusicProperties.AlbumTitle = album;
        if (!string.IsNullOrEmpty(coverUrl)) {
            updater.Thumbnail = RandomAccessStreamReference.CreateFromUri(new Uri(coverUrl));
        }
        updater.Update();
    }
}
```

### B. Discord Rich Presence (RPC)
Permette agli utenti Windows/Linux di mostrare ai propri amici su Discord cosa stanno ascoltando in tempo reale:
- **Application ID**: Creato su Discord Developer Portal.
- **Dati inviati**:
  - `Details`: Titolo della canzone.
  - `State`: Nome dell'artista.
  - `LargeImageKey`: `https://...` (copertina album).
  - `Timestamps`: Tempo rimanente per mostrare la barra di progresso su Discord.

---

## 🐧 3. Integrazione con Linux (MPRIS D-Bus)

Su Linux, per integrarsi con l'area notifiche di GNOME, KDE Plasma e la schermata di blocco, l'applicazione deve implementare l'interfaccia D-Bus `org.mpris.MediaPlayer2`:

```rust
// Esempio con Rust / Souvlaki o mpris-server
use mpris_server::{Metadata, Server, Time};

fn update_linux_media(title: &str, artist: &str, cover: &str, length_secs: u64) {
    let mut metadata = Metadata::new();
    metadata.set_title(title);
    metadata.set_artist(vec![artist]);
    metadata.set_art_url(cover);
    metadata.set_length(Time::from_secs(length_secs));
    // Notifica il demone D-Bus
}
```

---

## 📦 4. Funzionalità Desktop Indispensabili

1. **Riduzione a Icona nella System Tray (Vassoio di Sistema)**:
   - Quando l'utente chiude la finestra principale (tasto X), l'app continua la riproduzione in background e mostra un'icona nella barra di sistema con menu rapido (*Play/Pausa*, *Prossimo brano*, *Esci*).
2. **Scorciatoie Globali da Tastiera (Global Hotkeys)**:
   - Possibilità di cambiare brano o mutare l'audio anche mentre si sta giocando o lavorando su un'altra applicazione.
3. **Modalità Mini-Player Flottante ("Always on Top")**:
   - Una piccola finestra quadrata con copertina, titolo e controlli essenziali fissata sopra le altre finestre.

