# [IL PROGETTO AL MOMENTO E' IN WIP, POSSIBILI MALFUNZIONAMENTI PER ORA]

---

# 🎵 Preluded

Un music player web completo, tutto in un singolo file HTML.

🔗 **[preluded.vercel.app](https://preluded.vercel.app)**

---

## Di cosa si tratta

Preluded è un'app musicale che funziona nel browser, con un'interfaccia ispirata ad Apple Music: sfondo nero totale, tipografia Syne in grassetto, glassmorphism su ogni pannello, animazioni fluide. Dall'esterno sembra un'app nativa. Dentro è un singolo `index.html` da 180 KB e quasi 4000 righe.

---

## Cosa fa

Ha tutto quello che ci si aspetta da un player moderno. La **schermata principale** mostra i brani consigliati in una griglia. La **ricerca** permette di trovare singoli, album e artisti, con filtri dedicati. La **libreria** gestisce playlist personalizzabili e i brani preferiti. Cliccando su un artista o un album si apre la relativa pagina con discografia e tracklist.

Il **mini player** rimane fisso in basso mentre si naviga, e tocandolo si apre il **player a schermo intero**, con copertina animata, barra di progresso, controllo del volume e della velocità di riproduzione. C'è anche una **visualizzazione testi** con karaoke parola per parola e la possibilità di tradurli in italiano.

Altre funzioni: condivisione di un brano tramite **deep link** (con anteprima overlay), import di playlist da **CSV**, coda di riproduzione, supporto **PWA** (installabile come app), streaming adattivo via **dash.js**.

---

## Stack

HTML, CSS, JavaScript vanilla. Nessuna dipendenza npm, nessun bundler. L'unica libreria esterna è dash.js, caricata via CDN per lo streaming MPEG-DASH. Font: Overpass e Syne da Google Fonts. Licenza GPL-3.0.

---

## Struttura

```
web-music/
├── index.html          # Tutta l'app (3936 righe, 180 KB)
├── manifest.json       # PWA manifest
├── sw.js               # Service worker per uso offline
├── icons/              # Icone app per varie dimensioni
└── tools/              # Strumenti di supporto
```
