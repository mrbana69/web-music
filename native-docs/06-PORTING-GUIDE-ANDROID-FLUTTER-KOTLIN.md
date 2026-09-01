# 🤖 Preluded - Guida Implementazione Android (Kotlin / Jetpack Compose o Flutter)

Questa guida fornisce le indicazioni tecniche e gli snippet di codice per creare l'applicazione nativa **Android** di Preluded con riproduzione continua a schermo spento e controlli multimediali.

---

## 🛠️ Opzione A: Sviluppo Nativo in Kotlin (Consigliato)

### 1. Dipendenze `build.gradle.kts`
```kotlin
dependencies {
    // Jetpack Media3 (ExoPlayer moderno per Android)
    implementation("androidx.media3:media3-exoplayer:1.3.0")
    implementation("androidx.media3:media3-session:1.3.0")
    implementation("androidx.media3:media3-ui:1.3.0")
    
    // Jetpack Compose & Material 3
    implementation("androidx.compose.material3:material3:1.2.1")
    implementation("io.coil-kt:coil-compose:2.6.0") // Caricamento immagini & cache
    implementation("androidx.palette:palette-ktx:1.0.0") // Estrazione colore dinamico
    
    // Rete & Coroutines
    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-gson:2.11.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
}
```

### 2. Permessi in `AndroidManifest.xml`
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application ...>
        <!-- Servizio Audio in Background -->
        <service
            android:name=".playback.MusicService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="androidx.media3.session.MediaSessionService" />
            </intent-filter>
        </service>
    </application>
</manifest>
```

### 3. Servizio di Riproduzione Media3 (`MusicService.kt`)
```kotlin
package com.preluded.music.playback

import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import android.net.Uri

class MusicService : MediaSessionService() {
    private var mediaSession: MediaSession? = null
    private lateinit var player: ExoPlayer

    override fun onCreate() {
        super.onCreate()
        player = ExoPlayer.Builder(this)
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(androidx.media3.common.C.WAKE_MODE_NETWORK)
            .build()

        mediaSession = MediaSession.Builder(this, player).build()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return mediaSession
    }

    override fun onDestroy() {
        mediaSession?.run {
            player.release()
            release()
            mediaSession = null
        }
        super.onDestroy()
    }
}
```

### 4. Riproduzione Traccia con ExoPlayer
```kotlin
fun playTrack(trackId: String, title: String, artist: String, coverUrl: String) {
    val streamUrl = "https://preluded.vercel.app/api/stream?id=$trackId"
    
    val metadata = MediaMetadata.Builder()
        .setTitle(title)
        .setArtist(artist)
        .setArtworkUri(Uri.parse(coverUrl))
        .build()

    val mediaItem = MediaItem.Builder()
        .setUri(streamUrl)
        .setMediaId(trackId)
        .setMediaMetadata(metadata)
        .build()

    player.setMediaItem(mediaItem)
    player.prepare()
    player.play()
}
```

### 5. Schermata Testi Sincronizzati in Compose (`LyricsScreen.kt`)
```kotlin
@Composable
fun LyricsScreen(
    lyrics: List<LyricLine>,
    currentTime: Double,
    dominantColor: Color,
    onLineClick: (Double) -> Unit
) {
    val activeIndex = remember(currentTime, lyrics) {
        lyrics.indexOfLast { currentTime + 0.15 >= it.timeInSeconds }.coerceAtLeast(0)
    }
    val listState = rememberLazyListState()

    LaunchedEffect(activeIndex) {
        if (activeIndex in lyrics.indices) {
            listState.animateScrollToItem(index = activeIndex, scrollOffset = -300)
        }
    }

    LazyColumn(
        state = listState,
        modifier = Modifier.fillMaxSize().padding(horizontal = 24.dp)
    ) {
        itemsIndexed(lyrics) { index, line ->
            val isActive = index == activeIndex
            Text(
                text = line.text,
                fontSize = if (isActive) 24.sp else 18.sp,
                fontWeight = if (isActive) FontWeight.Bold else FontWeight.Normal,
                color = if (isActive) Color.White else Color.White.copy(alpha = 0.35f),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 12.dp)
                    .clickable { onLineClick(line.timeInSeconds) }
            )
        }
    }
}
```

---

## 🎯 Opzione B: Sviluppo Cross-Platform con Flutter

Se preferisci una singola base di codice per Android, Windows e Linux:
- **Audio Engine**: `package:just_audio` (gestione stream e buffer) + `package:audio_service` (integrazione MediaSession su Android/iOS/Desktop).
- **Rete**: `package:dio` o `package:http`.
- **Estrazione Colore**: `package:palette_generator`.
- **Database Locale**: `package:hive_flutter` o `package:isar`.

