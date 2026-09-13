# 🔐 Preluded - Autenticazione Google OAuth & Sincronizzazione Libreria

Questo documento descrive il protocollo di autenticazione con Google, i permessi richiesti e l'algoritmo di importazione selettiva (100% Opt-In) della musica da YouTube Music.

---

## 🔑 1. Configurazione Google OAuth 2.0

### A. Parametri di Configurazione
- **Client ID**: Configurato nella Google Cloud Console (progetto verificato di Emiliano Bana).
- **Ambito Permessi (Scopes)**:
  - `openid`
  - `https://www.googleapis.com/auth/userinfo.profile`
  - `https://www.googleapis.com/auth/userinfo.email`
  - `https://www.googleapis.com/auth/youtube.readonly` (necessario per visualizzare le playlist e i brani con Mi Piace).

### B. Flussi di Autenticazione Supportati
1. **Flusso App Mobile (Android - Credential Manager o Custom Chrome Tabs)**:
   - Apre la schermata di login sicura di Google e ritorna l'`id_token` e l'`access_token`.
2. **Flusso Desktop (Windows / Linux - Loopback Local Server o Device Code Flow)**:
   - Apre il browser predefinito su `https://preluded.vercel.app/api/auth/google/login` e riceve il token tramite redirect su `http://localhost:<porta_locale>/callback` oppure usa il Device Code Flow (`/api/auth/yt/get-code`).

---

## 📥 2. Algoritmo di Importazione Libreria (100% Opt-In)

> [!IMPORTANT]
> **Regola Fondamentale di UX**: Nessuna playlist o brano deve essere importato in automatico senza che l'utente abbia espressamente selezionato le caselle corrispondenti nel modale di importazione.

### A. Step 1: Caricamento dell'Elenco degli Elementi Disponibili
Dopo il login con successo, il client interroga le YouTube Data API v3 utilizzando l'`access_token`:

1. **Recupero Brani con "Mi Piace" (Liked Music)**:
   - Interrogare la playlist speciale con ID `LM` (YouTube Music Liked Music) o `LL` (YouTube Liked Videos).
   - Filtrare solo le tracce musicali effettive:
     $$\text{isMusicTrack} = \text{item.snippet.categoryId} == "10" \lor \text{hasArtistSeparator(title)}$$
2. **Recupero Playlist Create dall'Utente**:
   - Chiamata a `GET https://www.googleapis.com/youtube/v3/playlists?part=snippet,contentDetails&mine=true&maxResults=50`.

### B. Step 2: Mostrare il Modale di Selezione Utente
Il client mostra una finestra di dialogo con caselle di controllo **deselezionate per impostazione predefinita** (*unchecked by default*):
- `[ ] Importa Brani con "Mi Piace" (X canzoni trovate)`
- `[ ] Playlist 1: "Gym & Workout" (Y canzoni)`
- `[ ] Playlist 2: "Chill Lofi" (Z canzoni)`

### C. Step 3: Conferma e Sincronizzazione Locale
- Se l'utente preme **"Annulla"** o conferma con **0 caselle selezionate** $\rightarrow$ Nessuna modifica viene apportata alla libreria locale.
- Per ogni elemento spuntato:
  1. Scaricare gli elementi della playlist (`playlistItems.list`).
  2. Normalizzare i dati nel formato standard `Track`.
  3. Aggiungere alla lista locale `state.playlists` o `state.likedSongs` senza duplicare i brani già presenti (controllo su `item.id`).
  4. Salvare nello storage locale persistente.

---

## 💾 3. Struttura dei Dati Salvati in Locale

Nel database o file JSON locale dell'app:
```json
{
  "user_profile": {
    "name": "Emiliano Bana",
    "email": "user@gmail.com",
    "avatar": "https://lh3.googleusercontent.com/..."
  },
  "liked_songs": [
    {
      "id": "videoId1",
      "title": "Song Title",
      "artist": { "name": "Artist Name" },
      "cover": "https://...",
      "duration": 210,
      "addedAt": 1710000000000
    }
  ],
  "playlists": [
    {
      "id": "pl_1710000000000",
      "name": "I Miei Preferiti",
      "songs": [ ... ]
    }
  ],
  "history": [ ... ]
}
```

