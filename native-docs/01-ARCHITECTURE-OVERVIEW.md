# 🎼 Preluded - Architettura di Sistema Completa

Questo documento fornisce la visione d'insieme dell'architettura di Preluded per replicare fedelmente l'esperienza su **Android (Kotlin / Jetpack Compose o Flutter)**, **Windows (WinUI 3 / C# o Tauri/Flutter Desktop)** e **Linux (GTK / Qt / Tauri)**.

---

## 🏗️ 1. Diagramma dei Componenti

```
+-------------------------------------------------------------------------+
|                              CLIENT APP                                 |
|   (Android App / Windows App / Linux App / Web Client)                  |
|                                                                         |
|  +---------------------+   +---------------------+   +----------------+ |
|  |  UI / Design System |   |  Audio Player Engine|   | Synced Lyrics  | |
|  |  - Player & Queue   |   |  - ExoPlayer/Media3 |   | Engine (LRC)   | |
|  |  - Home/Search/Lib  |   |  - MediaSession/Lock|   | - Auto-scroll  | |
|  +---------------------+   +---------------------+   +----------------+ |
|            |                          |                       |         |
|            +--------------------------+-----------------------+         |
|                                       |                                 |
|                             +-------------------+                       |
|                             | State & Storage   |                       |
|                             | - SQLite/LocalDB  |                       |
|                             | - Queue & History |                       |
|                             +-------------------+                       |
+---------------------------------------|---------------------------------+
                                        | (HTTPS REST Calls)
                                        v
+-------------------------------------------------------------------------+
|                           PRELUDED BACKEND                              |
|                          (Node.js / Express)                            |
|                                                                         |
|  +-------------------------------------------------------------------+  |
|  | API Gateway & Routing (/api/*)                                    |  |
|  | - Rate limiting, CORS, response caching                           |  |
|  +-------------------------------------------------------------------+  |
|          |                  |                 |               |         |
|          v                  v                 v               v         |
|  +---------------+  +---------------+  +--------------+ +-------------+ |
|  | YouTube Music |  | Stream Proxy  |  | Synced Lyrics| | Google OAuth| |
|  | Service       |  | & Transcoding |  | LRCLIB / YT  | | & YouTube   | |
|  | (INNERTUBE)   |  | (Audio Range) |  | Fallback     | | Data API v3 | |
|  +---------------+  +---------------+  +--------------+ +-------------+ |
+-------------------------------------------------------------------------+
```

---

## 🔄 2. Flusso di Funzionamento End-to-End

### A. Avvio dell'Applicazione
1. **Inizializzazione Stato**: Il client carica da storage locale (`SQLite`, `SharedPreferences`, o `LocalStorage`):
   - Impostazioni audio (volume, ripetizione, shuffle, crossfade).
   - Playlist create dall'utente e brani preferiti.
   - Ultima coda di riproduzione salvata (se presente).
2. **Caricamento Home Feed**:
   - Il client esegue `GET /api/home` per ottenere i caroselli:
     - **Scelte rapide / Quick Picks** (personalizzate o trending).
     - **Nuove uscite / New Releases**.
     - **Playlist della community / Trending Hits**.
   - Mostra gli skeleton loading durante il fetch e popola le sezioni a griglia / carosello orizzontale.

### B. Ricerca (Live Search & Instant Results)
1. L'utente digita una query nel campo di ricerca con debounce di `250ms`.
2. Il client invia `GET /api/search?s=<query>` (oppure `?a=<artista>`, `?al=<album>`).
3. Il client riceve la lista dei brani con:
   - `id` (YouTube Video ID).
   - `title`, `artist`, `album`.
   - Copertina (`cover`).
   - Durata (`duration` in secondi).

### C. Riproduzione Audio & Streaming Hi-Fi
1. L'utente tocca un brano:
   - Se tocca un singolo brano da una lista, l'app popola la **Queue** con la traccia e opzionalmente genera il **Radio Mix** (`GET /api/mix?id=<trackId>`).
2. **Audio URL Resolution**:
   - Il client richiede `GET /api/track?id=<trackId>` (restituisce un manifest audio con i flussi diretti AAC/Opus).
   - In alternativa per mobile/desktop nativo: usa direttamente l'endpoint di streaming proxy:  
     `https://preluded.vercel.app/api/stream?id=<trackId>`.
3. **Player Nativo**:
   - Il motore audio (ExoPlayer su Android, MediaFoundation su Windows, GStreamer su Linux) apre lo stream con supporto HTTP Range Requests (scrubbing istantaneo).
   - Aggiorna i metadati di sistema (`MediaSession` / `MPRIS` / `SystemMediaTransportControls`):
     - Titolo, artista, copertina album, durata e posizione corrente.

### D. Testi Sincronizzati (Synced Lyrics)
1. In parallelo alla riproduzione, il client richiede `GET /api/lyrics?title=<title>&artist=<artist>&duration=<seconds>`.
2. Il server interroga in priorità **LRCLIB** e in fallback **YouTube Music Lyrics**.
3. Il client riceve un payload con:
   - `syncedLyrics`: stringa in formato standard LRC (es. `[00:14.20] Testo della canzone...`).
   - `plainLyrics`: testo non sincronizzato di fallback.
4. Il motore di sincronizzazione dell'app fa il parsing dei timestamp al millisecondo e calcola quale verso è attivo rispetto a `audioPlayer.currentPosition`, applicando lo scroll morbido e l'evidenziazione fluorescente.

---

## 📱 3. Modello di Dati Principale (Data Contracts)

### Struttura Traccia (`Track`)
```json
{
  "id": "dQw4w9WgXcQ",
  "title": "Never Gonna Give You Up",
  "artist": {
    "name": "Rick Astley",
    "id": "UCuAXFkgsw1L7xaCfnd5JJOw"
  },
  "album": {
    "title": "Whenever You Need Somebody",
    "id": "MPREb_...",
    "cover": "https://lh3.googleusercontent.com/..."
  },
  "cover": "https://lh3.googleusercontent.com/...",
  "duration": 213,
  "source": "youtube"
}
```

### Struttura Playlist (`Playlist`)
```json
{
  "id": "pl_1710000000000",
  "name": "I Miei Preferiti",
  "cover": "https://...",
  "itemCount": 15,
  "songs": [ /* Array di Track */ ]
}
```

