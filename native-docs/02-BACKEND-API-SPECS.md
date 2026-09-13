# 🔌 Preluded - Specifiche API Backend

Questo documento elenca tutti gli endpoint esposti dal backend di Preluded, con parametri, formati di richiesta e risposta, e codici di stato.

**Base URL di Produzione**: `https://preluded.vercel.app`  
**Base URL di Sviluppo Locale**: `http://localhost:3000`

---

## 📑 Indice degli Endpoint

1. [Health Check](#1-health-check)
2. [Home Feed & Quick Picks](#2-home-feed--quick-picks)
3. [Ricerca Brani, Artisti, Album](#3-ricerca)
4. [Risoluzione Audio & Streaming](#4-risoluzione-audio--streaming)
5. [Testi Sincronizzati (Lyrics)](#5-testi-sincronizzati)
6. [Radio Mix & Brani Simili](#6-radio-mix--brani-simili)
7. [Dettagli Artista & Album](#7-dettagli-artista--album)
8. [Autenticazione Google OAuth & Libreria](#8-autenticazione-google-oauth)

---

## 1. Health Check

### `GET /health`
Verifica lo stato del server.
- **Risposta** (`200 OK`):
```json
{
  "ok": true,
  "service": "preluded-backend",
  "timestamp": 1710000000000
}
```

---

## 2. Home Feed & Quick Picks

### `GET /api/home`
Restituisce le sezioni complete della home page di YouTube Music (Quick Picks, Nuove uscite, Playlist di tendenza).
- **Risposta** (`200 OK`):
```json
{
  "ok": true,
  "sections": [
    {
      "title": "Scelte rapide",
      "items": [
        {
          "id": "videoId1",
          "title": "Song Title",
          "artist": { "name": "Artist Name", "id": "channelId" },
          "album": { "title": "Album Name" },
          "cover": "https://...",
          "duration": 195
        }
      ]
    },
    {
      "title": "I più ascoltati della community",
      "items": [ ... ]
    }
  ]
}
```

### `GET /api/quick-picks`
Restituisce l'array dei brani per il carosello delle scelte rapide.
- **Parametri opzionali**: `token` (Google OAuth Access Token) per personalizzare i consigli.
- **Risposta** (`200 OK`):
```json
{
  "ok": true,
  "items": [ /* Array di Track */ ]
}
```

---

## 3. Ricerca

### `GET /api/search`
Cerca brani, artisti o album.
- **Parametri Query**:
  - `s`: Query testuale per brani (es. `?s=The%20Weeknd%20Blinding%20Lights`).
  - `a`: Query per artisti (es. `?a=Daft%20Punk`).
  - `al`: Query per album (es. `?al=Random%20Access%20Memories`).
- **Risposta** (`200 OK`):
```json
{
  "status": "success",
  "data": {
    "items": [
      {
        "id": "4NRXx6U8ABQ",
        "title": "Blinding Lights",
        "artist": { "name": "The Weeknd", "id": "UC0WP5P-ufpRfjbNrmOWwLBQ" },
        "album": { "title": "After Hours", "cover": "https://..." },
        "cover": "https://...",
        "duration": 200
      }
    ]
  }
}
```

---

## 4. Risoluzione Audio & Streaming

### `GET /api/stream?id=<videoId>`
**Endpoint consigliato per player nativi mobile e desktop**.  
Funziona come audio proxy HTTP trasparente con supporto per `Accept-Ranges: bytes`.
- **Parametri**: `id` (YouTube Video ID).
- **Headers supportati**: `Range: bytes=0-` (fondamentale per seeking istantaneo).
- **Risposta**: Stream binario `audio/webm` o `audio/mp4` a bitrate massimo (~160kbps Opus / 256kbps AAC).

### `GET /api/track?id=<videoId>`
Restituisce il manifest decodificato in formato JSON/Base64 contenente i link diretti ai flussi audio di Google CDN.
- **Risposta** (`200 OK`):
```json
{
  "status": "success",
  "data": {
    "manifest": "<base64_encoded_manifest>",
    "info": {
      "id": "4NRXx6U8ABQ",
      "title": "Blinding Lights",
      "artist": "The Weeknd",
      "duration": 200
    }
  }
}
```

### `GET /api/stream-url?videoId=<videoId>`
Restituisce direttamente la URL CDN di riproduzione.
- **Risposta** (`200 OK`):
```json
{
  "ok": true,
  "directUrl": "https://rr3---sn-....googlevideo.com/videoplayback?..."
}
```

---

## 5. Testi Sincronizzati (Lyrics)

### `GET /api/lyrics`
Restituisce i testi sincronizzati al millisecondo in formato LRC.
- **Parametri Query**:
  - `title`: Titolo del brano (es. `Starboy`).
  - `artist`: Nome dell'artista (es. `The Weeknd`).
  - `duration`: Durata in secondi (opzionale, per disambiguare le versioni).
  - `id`: YouTube Video ID (per fallback su YouTube Music).
- **Risposta** (`200 OK`):
```json
{
  "ok": true,
  "source": "lrclib",
  "syncedLyrics": "[00:10.50] I'm tryna put you in the worst mood, ah\n[00:13.20] P1 cleaner than your church shoes, ah\n[00:15.80] ...",
  "plainLyrics": "I'm tryna put you in the worst mood, ah\nP1 cleaner than your church shoes, ah..."
}
```

---

## 6. Radio Mix & Brani Simili

### `GET /api/mix?id=<videoId>`
Genera una coda infinita di brani coerenti con la traccia selezionata (YouTube Radio Mix).
- **Risposta** (`200 OK`):
```json
{
  "ok": true,
  "items": [ /* Array di 25-50 tracce simili */ ]
}
```

---

## 7. Dettagli Artista & Album

### `GET /api/artist?id=<channelId>&name=<artistName>`
Restituisce biografia, top songs, album e singoli dell'artista.

### `GET /api/album?id=<browseId>`
Restituisce la copertina ad alta risoluzione, anno di pubblicazione e l'elenco completo delle tracce con numero di traccia e durate.

---

## 8. Autenticazione Google OAuth

### `GET /api/auth/google/login`
Restituisce l'URL di autorizzazione OAuth 2.0 per il flusso Web/App:
- Scopes: `openid`, `profile`, `email`, `https://www.googleapis.com/auth/youtube.readonly`.

### `GET /api/auth/google/quick-picks?token=<googleAccessToken>`
Restituisce le scelte rapide personalizzate sul reale ascolto dell'utente su YouTube Music.

