# CLAUDE.md - Preluded Music Agent Instructions

> **MANDATORY INSTRUCTIONS FOR CLAUDE CODE AND ALL AI AGENTS WORKING ON THIS REPOSITORY**
> Read this file thoroughly before making ANY modification to this codebase.

---

## 🚨 ABSOLUTE PROJECT CONSTRAINTS (DO NOT VIOLATE)

1. **DO NOT MODIFY LOGIN ON iOS**:
   - The user has explicitly stated: *"non modificare il login su ios perche la funziona!"*
   - The Google Login flow and authentication architecture on **iOS** is fully functional. Any agent touching iOS authentication or its related services will break working functionality. **LEAVE iOS LOGIN UNTOUCHED.**

2. **TEST MULTIPLE TIMES BEFORE RELEASING**:
   - The user requires that whenever an app package (.exe or .apk) is built and installed, it **MUST work out-of-the-box** without crashes, silent audio failures, black screens, or layout overflows.
   - Run `dart analyze lib` (must have 0 errors).
   - Run `flutter test test/mega_app_test.dart` (all 21+ tests must pass).
   - Test screen layouts on both wide (desktop) and narrow (mobile phone) viewports.

3. **GIT COMMIT RULES**:
   - Do not commit to git branches or switch branches without explicit user permission. Follow the user's workflow direction.

---

## 📌 PROJECT ARCHITECTURE & TECH STACK

- **Framework**: Flutter (Dart 3.x), multi-platform targeting Windows, Android, iOS, and Web.
- **State Management**: `Provider` (`PlayerState`, `LibraryState`).
- **Audio Engine**: `just_audio` + `audio_service` + custom `LocalStreamProxy`.
- **API Engine**: `ApiService` querying YouTube Music InnerTube (WEB_REMIX client) with Apple Music / iTunes API enrichment for studio album covers.
- **Native Desktop Integration**: Windows SMTC (System Media Transport Controls) via WinRT/C++ channel (`smtc_manager.cpp` & `windows_smtc_service.dart`).

---

## 🎨 UI/UX DESIGN SYSTEM SPECIFICATIONS

### 1. Typography & Colors
- **Headings & Brand**: `AppTheme.syne` (bold, geometric, modern audio identity).
- **Body, Metadata, Durations**: `AppTheme.inter` (ultra-clean readability).
- **Theme Palette**:
  - Background: Deep Obsidian `#131317` / `#0E0E11`
  - Cards & Containers: `#1B1B1F`, `#201F23`, `#353438`
  - Accent Colors: `#FA2D48` (Primary Coral Red), `#FF525E` (High-contrast glow)
  - Borders: `Colors.white.withOpacity(0.06)` to `0.12`
- **NO False Badges**: Never render *"MASTER 24-BIT / 96KHZ DOLBY ATMOS"* or fake lossless claims on artist or album headers.

### 2. Home Feed & "Scelte rapide" (Quick Picks)
- **Mood / Category Filter Bar (`MoodChipsBar`)**:
  - Located at the top of the home screen.
  - Contains mood pills: `Podcast`, `Energia pura`, `Relax`, `Benessere`, `Attività fisica`, `Festa`, `Tragitto giornaliero`, `Romantico`, `Malinconico`, `Concentrazione`, `Riposo`.
  - Tapping a mood sends the YouTube Music `params` token to `FEmusic_home` to update the feed dynamically.
- **Multi-Row 4-Item Grid Carousel (`QuickPicksGrid`)**:
  - Matches the official YouTube Music web/desktop design.
  - Header with title **Scelte rapide**, pill button **"Riproduci tutti"** (Play all), and arrow navigation buttons `<` and `>`.
  - Horizontally scrolling list of columns, where each column has **4 tracks stacked vertically**.
  - Each item: 48x48 rounded squircle cover, bold white title, subtitle with artist name and views/album, and heart like button.
  - Tap immediately plays the track and queues the 20 quick picks.
- **Personalized vs Listening History**:
  - `fetchQuickPicks()` queries `FEmusic_home` with user cookies to retrieve YouTube Music's algorithmic recommendations.
  - Listening history (`FEmusic_history`) is reserved exclusively for the dedicated section **"Di nuovo all'ascolto"**.

### 3. Artist Screen (`ArtistScreen`)
- **Responsive Layout**:
  - Desktop (> 750px): 60/40 dual column (Popular tracks on left, Tour/Bio on right).
  - Mobile (< 750px): Single-column vertical flow with horizontal discography carousel.
- **Popular Tracks**:
  - Each track row (`StitchTrackRow`) features index, square artwork, title, subtitle, duration, and **Heart (Like)** button. (Do not put lyrics icon here).
- **Discography Section**:
  - Real categorical breakdown: **Album**, **Singoli ed EP**, **Playlist**.
  - Interactive filter chips (*Tutto*, *Album*, *Singoli*, *Playlist*).
  - Must render even if artist has only singles or only albums (`_artist.albums.isNotEmpty || _artist.singles.isNotEmpty || _artist.playlists.isNotEmpty`).

### 4. Album Screen (`AlbumScreen`)
- Immersive ambient glow hero header.
- Individual track artwork passed down into each track row in the tracklist (`StitchTrackRow`).

### 5. Full Player Screen (`FullPlayerScreen`)
- Responsive:
  - Wide screens (>= 620px): Side-by-side layout (artwork centered on left, controls & scrubber on right).
  - Mobile portrait (< 620px): Dynamic vertical column with clamped artwork size and proportional spacing to prevent overflow on any device height.
- Swipe-down gesture to dismiss.

### 6. Navigation & MiniPlayer
- Desktop: Left sidebar navigation + floating bottom miniplayer.
- Mobile: Bottom navigation bar + floating squircle miniplayer pinned above the navigation bar.
- **Crucial**: All scrolling lists must have `160-180px` bottom padding (`SizedBox(height: 180)`) so the floating miniplayer never covers content.

---

## 🔊 AUDIO PLAYBACK & LOCALSTREAMPROXY ARCHITECTURE

### The Problem
YouTube enforces SABR / 1MB stream throttling (HTTP 403 Forbidden) on audio-only streams (`itag 140` and `251`) when requested without user PO tokens, causing playback to cut off around 30-60 seconds.

### The Solution (`LocalStreamProxy`)
1. **Priority 1: `itag 18`**: Standard MP4 container with stereo AAC audio and `ratebypass=yes`. This stream does NOT cut off at 1MB and streams continuously.
2. **Buffer Streaming**: `LocalStreamProxy` buffers upstream audio chunks in a local HTTP loopback server (`http://127.0.0.1:<port>/stream?id=...`).
3. **Deferred Headers**: HTTP 200 response headers are only sent after the first upstream byte is verified.

### ⚠️ Android Audio Troubleshooting Guide (For Android Agents)
When testing on Android, if the audio does not load:
1. **Localhost Binding**:
   - On Android, `LocalStreamProxy` binds to `InternetAddress.loopbackIPv4` (`127.0.0.1`).
   - Ensure `android:usesCleartextTraffic="true"` is set in `AndroidManifest.xml` (already configured).
   - Check if Android requires `InternetAddress.anyIPv4` (`0.0.0.0`) or if ExoPlayer fails to connect to `127.0.0.1`.
2. **Direct Stream Fallback**:
   - In `audio_handler.dart`, if `LocalStreamProxy` fails on Android, fallback directly to `track.streamUrl` using `AudioSource.uri(Uri.parse(streamUrl), headers: {...})`.
3. **AudioSession & WakeLock**:
   - Ensure `AudioSession.configure(const AudioSessionConfiguration.music())` is active on Android so OS power managers do not pause the audio stream.

---

## 🧪 VALIDATION CHECKLIST (RUN BEFORE REPORTING COMPLETION)

1. `dart analyze lib` -> 0 issues / errors.
2. `flutter test test/mega_app_test.dart` -> 21/21 passed.
3. Test Windows build: `flutter build windows --release` -> clean compilation.
4. Check that no false badges exist in any screen.
5. Verify that iOS login files were untouched.
