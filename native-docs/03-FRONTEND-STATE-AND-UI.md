# 🎨 Preluded - Gestione dello Stato e Componenti UI

Questo documento descrive la macchina a stati, le viste dell'interfaccia utente e l'interazione per replicare la UX su client nativi Android, Windows e Linux.

---

## 🧠 1. Macchina a Stati Principale (`AppState`)

In qualsiasi piattaforma (Kotlin StateFlow / Compose `remember`, Flutter `ChangeNotifier`/`Bloc`, C# `INotifyPropertyChanged`), lo stato globale deve contenere le seguenti proprietà:

```typescript
interface AppState {
  // Stato Riproduzione
  isPlaying: boolean;
  isBuffering: boolean;
  currentTime: number;       // in secondi (es. 45.2)
  duration: number;          // in secondi (es. 210.0)
  volume: number;            // 0.0 - 1.0
  isMuted: boolean;
  
  // Coda & Indice
  queue: Track[];
  currentIndex: number;
  originalQueue: Track[];    // usata per ripristinare l'ordine quando shuffle viene disattivato
  
  // Modalità di Riproduzione
  isShuffle: boolean;
  repeatMode: 'off' | 'all' | 'one';
  
  // Testi
  lyrics: {
    lines: Array<{ time: number; text: string }>;
    activeLineIndex: number;
    isLoading: boolean;
    hasLyrics: boolean;
  };
  
  // Libreria Locale
  likedSongs: Track[];
  playlists: Playlist[];
  history: Track[];
  
  // Utente / Google Session
  user: {
    isLoggedIn: boolean;
    name: string;
    email: string;
    picture: string;
    googleToken?: string;
  } | null;
  
  // UI & Tema
  currentTab: 'home' | 'search' | 'library' | 'artist' | 'album' | 'playlist';
  isFullPlayerOpen: boolean;
  dominantColor: string;     // Colore hex estratto dalla copertina corrente (es. "#FA2D48")
}
```

---

## 📱 2. Le Viste Principali della UI

### 🏠 1. Tab Home (`HomeView`)
- **Header**: Saluto personalizzato ("Buongiorno / Buonasera, [Nome]"), avatar profilo e pulsante impostazioni.
- **Carosello Scelte Rapide (Quick Picks)**: Griglia orizzontale a 2 righe con copertina, titolo e artista.
- **Sezioni Tematiche**: "I più ascoltati", "Nuove uscite", "Playlist consigliate".
- **Comportamento al Click**:
  - Tocco su un brano $\rightarrow$ Avvia la riproduzione immediata e carica il Radio Mix in background.
  - Tocco su una playlist $\rightarrow$ Apre la pagina playlist.

### 🔍 2. Tab Ricerca (`SearchView`)
- **Barra di Ricerca**: Campo input con icona lente, pulsante "cancella" (X) e debounce automatico di `250ms`.
- **Filtri a Pillola**: "Tutto", "Brani", "Artisti", "Album".
- **Lista Risultati**: Visualizzazione a righe con artwork (`50x50`), titolo in grassetto, artista/album, durata e menu contestuale a 3 puntini (`...`).

### 📚 3. Tab Libreria (`LibraryView`)
- **Sezione "Brani Preferiti" (Liked Songs)**: Card con icona cuore e gradiente rosso/arancio, indicante il numero totale di canzoni.
- **Lista Playlist**:
  - Pulsante **"+ Nuova Playlist"**.
  - Lista delle playlist create dall'utente (con copertina, titolo e numero di brani).
  - Tasto **"Importa CSV / YouTube"** per recuperare le playlist esterne.

---

## 🎵 3. I Componenti del Player

### 🎛️ Mini Player (Fisso in basso)
- Rimane visibile sopra la barra di navigazione quando un brano è in riproduzione.
- **Elementi**:
  - Mini copertina quadrata (`44x44` con angoli arrotondati a `8px`).
  - Titolo traccia (con scorrimento marquee se supera lo spazio disponibile) e Artista.
  - Tasto **Play / Pause** (`36x36`).
  - Tasto **Next (Brano Successivo)**.
  - Barra di avanzamento sottile (`2px` o `3px`) alla base del mini-player.
- **Interazione**: Tocco sul corpo del mini player $\rightarrow$ Apre a tutto schermo il **Full Player** con transizione fluida (slide-up).

### 🌌 Full Player (A Tutto Schermo)
- **Sfondo Dinamico**: Gradiente radiale sfocato generato dal colore dominante della copertina corrente (`backdrop-filter: blur(40px)`).
- **Header**: Pulsante freccia in giù (chiudi player) e pulsante menu traccia (condividi, aggiungi a playlist).
- **Artwork Grande**: Immagine quadrata ad alta risoluzione (`640x640`) con ombreggiatura morbida e angoli arrotondati (`20px`).
- **Info Traccia**: Titolo in grande (font Syne/Bold), Artista (cliccabile per aprire la pagina artista) e pulsante Cuore ("Mi Piace").
- **Seekbar (Barra di Scorrimento)**:
  - Cursore trascinabile con tempo trascorso a sinistra (`01:23`) e tempo totale/rimanente a destra (`03:45`).
- **Controlli di Riproduzione**:
  - Tasto **Shuffle (Casuale)**.
  - Tasto **Previous (Precedente)**.
  - Tasto **Play / Pause (Grande, accent colorato con effetto glow)**.
  - Tasto **Next (Successivo)**.
  - Tasto **Repeat (Ripeti: Spento $\rightarrow$ Ripeti Tutti $\rightarrow$ Ripeti Uno)**.
- **Tasti Funzione Inferiori**:
  - Pulsante **Testi (Lyrics)**: visualizza i testi sincronizzati a schermo intero.
  - Pulsante **Coda (Queue)**: mostra l'elenco dei brani successivi con drag-and-drop per riordinarli.
  - Pulsante **Aggiungi a Playlist**: apre il modale di selezione rapida con barra di ricerca interna.

---

## 🌈 4. Estrazione del Colore Dominante (Palette Dinamica)
Per un'esperienza immersiva uguale alla versione Web:
1. Quando cambia brano, estrarre i colori dominanti dalla bitmap della copertina:
   - **Android**: Utilizzare `androidx.palette.graphics.Palette.from(bitmap).generate()`.
   - **Windows (C#)**: Utilizzare `ColorThief.Net` o calcolare la media RGB dei pixel centrali.
   - **Linux / Flutter**: Utilizzare il package `palette_generator`.
2. Applicare il colore dominante come gradiente di background nel Player e come colore di evidenziazione dei testi attivi.

