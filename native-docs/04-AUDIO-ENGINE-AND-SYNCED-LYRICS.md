# 🔊 Preluded - Motore Audio & Testi Sincronizzati (LRC Engine)

Questo documento spiega come implementare il motore audio Hi-Fi con riproduzione in background e l'algoritmo di rendering dei testi sincronizzati al millisecondo.

---

## 🎧 1. Motore Audio & Streaming

### A. Sorgente Audio e Flusso
Per garantire la massima compatibilità e riproduzione istantanea:
- **URL di Stream**: `https://preluded.vercel.app/api/stream?id=<trackId>`
- **Formato**: WebM Opus (~160kbps) o MP4 AAC (~256kbps).
- **Buffer di Pre-caricamento**: Configurare il player con un buffer iniziale minimo di `2.5 secondi` per l'avvio immediato e un buffer target di `30 secondi`.

### B. Transizioni & Fade In/Out (Crossfade)
Nel passaggio tra due canzoni (sia manuale sia a fine brano):
1. Quando mancano `300ms` alla fine della traccia corrente, applicare un volume ramp-down:
   $$\text{volume}(t) = \text{maxVolume} \times (1 - \frac{t}{300\text{ms}})$$
2. All'avvio della nuova traccia, applicare un ramp-up da `0` a `maxVolume` in `300ms`.
Questo elimina i fastidiosi "click" o scatti audio.

### C. Gestione del Focus Audio (Audio Focus)
- **Chiamata in arrivo / Navigatore GPS**: Mettere in pausa o abbassare il volume (*ducking*).
- **Disconnessione cuffie/Bluetooth**: Mettere immediatamente in pausa la riproduzione (*Becoming Noisy*).

---

## 🎤 2. Algoritmo di Sincronizzazione dei Testi (LRC Parser)

### A. Formato File LRC
I testi arrivano dall'endpoint `/api/lyrics` nel formato standard:
```
[00:12.45] Testo del primo verso
[00:15.80] Testo del secondo verso
[00:19.10] Terzo verso sincronizzato
```

### B. Parser LRC in Pseudo-codice
```typescript
interface LyricLine {
  timeInSeconds: number; // es. 12.45
  text: string;
}

function parseLRC(rawLrc: string): LyricLine[] {
  const lines: LyricLine[] = [];
  const regex = /\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)/;
  
  const rawLines = rawLrc.split('\n');
  for (const line of rawLines) {
    const match = line.match(regex);
    if (match) {
      const minutes = parseInt(match[1], 10);
      const seconds = parseInt(match[2], 10);
      const milliseconds = parseFloat('0.' + match[3]);
      const timeInSeconds = (minutes * 60) + seconds + milliseconds;
      const text = match[4].trim();
      
      lines.push({ timeInSeconds, text });
    }
  }
  
  // Ordina temporalmente
  return lines.sort((a, b) => a.timeInSeconds - b.timeInSeconds);
}
```

### C. Individuazione della Linea Attiva in Tempo Reale
Durante l'evento `onPlaybackProgress(currentTime)` (aggiornato a 60fps o ad ogni tick di `50ms`):
```typescript
function getActiveLineIndex(lines: LyricLine[], currentTime: number): number {
  if (lines.length === 0) return -1;
  
  let activeIndex = 0;
  for (let i = 0; i < lines.length; i++) {
    // Applichiamo un offset anticipato di 150ms per compensare la latenza visiva umana
    if (currentTime + 0.15 >= lines[i].timeInSeconds) {
      activeIndex = i;
    } else {
      break;
    }
  }
  return activeIndex;
}
```

### D. Auto-Scroll Morbido e Interattività
1. **Centratura Automatica**: Quando `activeIndex` cambia, la lista dei testi esegue un scroll morbido (*smooth scroll*) per posizionare la riga attiva esattamente al **centro verticale dello schermo**.
2. **Stile Visivo**:
   - Riga attiva: Colore `#FFFFFF`, font-size ingrandito (`22px`), opacità `1.0`, testo fluorescente o evidenziato col colore del tema.
   - Righe passate e future: Colore `rgba(255, 255, 255, 0.35)`, font-size standard (`18px`).
3. **Seek al tocco (Tap to Seek)**:
   - Se l'utente tocca un verso qualsiasi della canzone, il player esegue istantaneamente un `audioPlayer.seekTo(line.timeInSeconds)` per saltare a quel preciso punto della traccia!

---

## 🔒 3. Integrazione con i Controlli di Sistema e Schermata di Blocco

Tutti i client nativi devono sincronizzarsi con il sottosistema multimediale dell'OS:

| Piattaforma | Framework Audio di Sistema | Funzionalità Richieste |
|---|---|---|
| **Android** | `MediaSessionService` / `MediaSessionCompat` | Notifica multimediale con artwork grande, seekbar sulla notifica (Android 13+), tasti Next/Prev/Play/Pause, supporto Android Auto. |
| **Windows** | `SystemMediaTransportControls` (SMTC) | Overlay volume Windows, tasti multimediali da tastiera, miniatura sulla barra delle applicazioni. |
| **Linux** | `MPRIS D-Bus Interface` (`org.mpris.MediaPlayer2`) | Integrazione con GNOME / KDE player widget, tasti multimediali e player nella lockscreen. |

### Payload dei Metadati di Sistema:
- **Title**: `track.title`
- **Artist**: `track.artist.name`
- **Album**: `track.album.title`
- **Artwork**: URL o bitmap locale (`640x640`)
- **Duration**: `track.duration * 1000` (in millisecondi)
- **Position**: `audioPlayer.currentPosition`
- **PlaybackState**: `STATE_PLAYING` / `STATE_PAUSED` / `STATE_BUFFERING`

