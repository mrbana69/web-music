# UI/UX & Audio Engine Architecture Specification

This document provides complete architectural specifications for UI/UX components and the audio streaming engine across Windows Desktop, Android Mobile, iOS, and Web.

---

## 1. UI/UX Architecture

### 1.1 Responsive Viewport Strategy
The application dynamically adapts its layout based on screen geometry:
- **Desktop / Wide Landscape (`width >= 750px`)**:
  - `MainScreen`: Left navigation rail / sidebar (230px fixed width) with brand header and navigation items (*Home*, *Cerca*, *Libreria*).
  - Content area: Centered view with floating `MiniPlayer` (max width 880px) pinned 16px from the bottom.
  - `ArtistScreen`: 60/40 split view. Popular tracks on the left (flex 7), biography and highlight cards on the right (flex 5). Discography rendered as a multi-column responsive grid.
  - `FullPlayerScreen`: Centered side-by-side view (album artwork on left flex 5, scrubber and controls on right flex 6).
- **Mobile / Compact (`width < 750px`)**:
  - `MainScreen`: Bottom navigation bar (`NavigationBar`) with frosted dark glass effect.
  - Content area: Full width with `MiniPlayer` docked right above the bottom navigation bar.
  - `ArtistScreen`: Single column layout. Hero header, followed by Top Tracks list, horizontal scrolling Discography carousel, and Biography card.
  - `FullPlayerScreen`: Vertical column layout with dynamically clamped artwork height (`clamp(180, maxArt)`) and proportional padding, ensuring zero pixel overflow even on 5-inch screens.
  - Swipe-down gesture to dismiss the full player (`onVerticalDragEnd` velocity > 300).

### 1.2 Home Feed & "Scelte rapide" (YouTube Music Alignment)
- **Mood Chips Bar (`MoodChipsBar`)**:
  - Horizontal list of pills at the top of the home screen.
  - Fetched dynamically from `FEmusic_home` via `ApiService.fetchHomeChips()`.
  - Default moods: `Podcast`, `Energia pura`, `Relax`, `Benessere`, `Attività fisica`, `Festa`, `Tragitto giornaliero`, `Romantico`, `Malinconico`, `Concentrazione`, `Riposo`.
  - Selecting a mood passes `params` to `FEmusic_home` to reload the feed with that mood's tailored tracks.
- **Scelte rapide 4-Row Column Grid (`QuickPicksGrid`)**:
  - Matches YouTube Music's desktop & mobile grid: 4 rows per column, scrolling horizontally.
  - Header:
    - Bold title: "Scelte rapide".
    - Pill button: "Riproduci tutti" with Play icon (starts playback from track 0 and sets all 20 tracks as queue).
    - Arrow buttons: `<` and `>` on desktop to scroll horizontally by page.
  - Track tiles: 48x48 rounded squircle cover, title (bold Syne), subtitle (Inter with artist name and views/album metadata), and quick Like (heart) toggle.
- **Listening History Separation**:
  - Personalized recommendations from `FEmusic_home` are strictly separated from raw playback history (`FEmusic_history` / `library.history`), which is rendered in its own section "Di nuovo all'ascolto".

### 1.3 Discography & Album Improvements
- **True Categorization**:
  - Artist discography parses InnerTube and Tidal data into three distinct lists: `albums`, `singles` (Singoli ed EP), and `playlists`.
  - Filter chips (*Tutto*, *Album*, *Singoli*, *Playlist*) filter the discography seamlessly.
  - Guard condition: renders whenever any category has items (`_artist.albums.isNotEmpty || _artist.singles.isNotEmpty || _artist.playlists.isNotEmpty`).
- **Album Tracklist Artwork**:
  - Track rows in `AlbumScreen` receive the parent album cover if individual track cover is missing or low-res, preventing blank or placeholder covers in the tracklist.
- **Badge Policy**:
  - No false badges ("MASTER 24-BIT / 96KHZ DOLBY ATMOS") are allowed. Only genuine explicit tags (`[E]`) and top track indicators (`TOP`) are permitted.

---

## 2. Audio Streaming Engine & Android Optimization

### 2.1 The YouTube Streaming Problem
When requesting raw YouTube audio streams (`itag 140` / `251` from `googlevideo.com`) without a valid user PO token, YouTube terminates the connection after ~1MB (returning HTTP 403 Forbidden).

### 2.2 LocalStreamProxy Architecture
1. **Primary Stream Selection**:
   - Priority 1: `itag 18` (MP4 container, AAC stereo audio, `ratebypass=yes`). This stream is not subject to the 1MB SABR cutoff and plays smoothly to completion.
   - Priority 2: Audio-only streams (`itag 140` / `251`) with chunked proxying.
2. **Local HTTP Server**:
   - `LocalStreamProxy` spins up a local `HttpServer` listening on loopback (`http://127.0.0.1:<port>/stream?id=<trackId>`).
   - Upstream audio data is fetched via HTTP client with proper headers (`User-Agent`, `Referer`, `Range`) and piped to the player.
   - HTTP response headers are only sent after receiving the first upstream chunk (`headerSent = true`), preventing empty response errors.

### 2.3 Android Audio Playback Troubleshooting
If audio does not load on Android when testing the APK:
1. **Socket Binding**:
   - In `local_stream_proxy.dart`, ensure `HttpServer.bind(InternetAddress.loopbackIPv4, 0)` is reachable by Android's ExoPlayer. If Android security restricts `127.0.0.1`, try binding to `InternetAddress.anyIPv4` (`0.0.0.0`) or using Android's network security configuration.
2. **ExoPlayer Cleartext Configuration**:
   - Android 9+ blocks cleartext HTTP by default. `AndroidManifest.xml` must include `android:usesCleartextTraffic="true"`.
3. **Direct Fallback in AudioHandler**:
   - In `audio_handler.dart`, wrap `_player.setAudioSource(AudioSource.uri(Uri.parse(localProxyUrl)))` in a try-catch. If the local proxy fails to connect on Android, fallback immediately to:
     ```dart
     final directStreamUrl = await _api.resolveAudioStream(track.id);
     if (directStreamUrl != null) {
       await _player.setAudioSource(
         AudioSource.uri(
           Uri.parse(directStreamUrl),
           headers: {
             'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36...',
             'Referer': 'https://music.youtube.com/',
           },
         ),
       );
     }
     ```
4. **Android Background Permissions**:
   - `AndroidManifest.xml` must contain:
     - `android.permission.INTERNET`
     - `android.permission.WAKE_LOCK`
     - `android.permission.FOREGROUND_SERVICE`
     - `android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK`
     - `android.permission.POST_NOTIFICATIONS`

---

## 3. Important Notes on iOS Login

> **DO NOT TOUCH iOS AUTHENTICATION**
> The iOS login flow works properly and has been validated by the user. Do not modify `google_login_screen.dart` iOS specific branches, URL schemes, or authentication handlers.
