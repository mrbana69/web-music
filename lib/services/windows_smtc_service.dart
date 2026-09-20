import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';

class WindowsSmtcService {
  static const MethodChannel _channel = MethodChannel('com.preluded.music/smtc');
  static bool get isSupported => !kIsWeb && Platform.isWindows;

  static void initialize(AudioHandler audioHandler) {
    if (!isSupported) return;

    _channel.setMethodCallHandler((call) async {
      try {
        switch (call.method) {
          case 'onPlay':
            await audioHandler.play();
            break;
          case 'onPause':
            await audioHandler.pause();
            break;
          case 'onNext':
            await audioHandler.skipToNext();
            break;
          case 'onPrevious':
            await audioHandler.skipToPrevious();
            break;
          case 'onStop':
            await audioHandler.stop();
            break;
        }
      } catch (e) {
        // Ignored in non-interactive/detached contexts
      }
    });

    // Listen to mediaItem changes to update Title, Artist, Album, Thumbnail
    audioHandler.mediaItem.listen((item) {
      if (item != null) {
        updatePlayback(
          title: item.title,
          artist: item.artist ?? '',
          album: item.album ?? '',
          thumbnailUrl: item.artUri?.toString() ?? '',
          isPlaying: audioHandler.playbackState.value.playing,
        );
      }
    });

    // Listen to playbackState changes to update Play/Pause status
    audioHandler.playbackState.listen((state) {
      setPlaybackStatus(state.playing);
    });
  }

  static Future<void> updatePlayback({
    required String title,
    required String artist,
    required String album,
    required String thumbnailUrl,
    required bool isPlaying,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('updatePlayback', {
        'title': title,
        'artist': artist,
        'album': album,
        'thumbnailUrl': thumbnailUrl,
        'isPlaying': isPlaying,
      });
    } catch (_) {}
  }

  static Future<void> setPlaybackStatus(bool isPlaying) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('setPlaybackStatus', {
        'isPlaying': isPlaying,
      });
    } catch (_) {}
  }

  static Future<void> clear() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('clearPlayback');
    } catch (_) {}
  }
}

