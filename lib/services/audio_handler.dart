import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import '../config/app_config.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'local_stream_proxy.dart';
import 'windows_smtc_service.dart';

Future<AudioHandler> initAudioService(ApiService apiService, StorageService storageService) async {
  final handler = await AudioService.init(
    builder: () => PreludedAudioHandler(apiService, storageService),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.preluded.music.channel.audio',
      androidNotificationChannelName: 'Preluded Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
  WindowsSmtcService.initialize(handler);
  return handler;
}

class PreludedAudioHandler extends BaseAudioHandler with SeekHandler {
  final ApiService _api;
  final StorageService _storage;
  final AudioPlayer _player = AudioPlayer();
  final LocalStreamProxy _localProxy = LocalStreamProxy();

  List<Track> _tracksQueue = [];
  int _currentIndex = 0;
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;
  bool _shouldPlayWhenReady = false;
  bool _isStartingPendingPlayback = false;

  PreludedAudioHandler(this._api, this._storage) {
    _initAudioSession();
    _initPlayerListeners();
    _localProxy.start();
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      print('AudioSession init error: $e');
    }
  }

  AudioPlayer get player => _player;
  List<Track> get currentQueue => _tracksQueue;
  int get currentIndex => _currentIndex;
  Track? get currentTrack => (_currentIndex >= 0 && _currentIndex < _tracksQueue.length)
      ? _tracksQueue[_currentIndex]
      : null;

  void _broadcastState() {
    final playing = _player.playing || _shouldPlayWhenReady;
    final procState = const {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    }[_player.processingState] ?? AudioProcessingState.idle;

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: procState,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
    ));
  }

  void _initPlayerListeners() {
    // 1. Playback Events
    _player.playbackEventStream.listen((_) => _broadcastState());

    // 2. Track Completion & State Changes (emits on playing and processingState change)
    _player.playerStateStream.listen((state) {
      _broadcastState();

      // Auto-start playback on Windows/platforms where play() during Opening was deferred
      if (_shouldPlayWhenReady &&
          (state.processingState == ProcessingState.ready ||
           state.processingState == ProcessingState.buffering)) {
        _startPendingPlayback();
      }
      if (state.playing) {
        _shouldPlayWhenReady = false;
      }

      if (state.processingState == ProcessingState.completed) {
        if (_loopMode == LoopMode.one) {
          _player.seek(Duration.zero);
          _player.play();
        } else {
          skipToNext();
        }
      }
    });

    // 3. Playing Stream
    _player.playingStream.listen((_) => _broadcastState());

    // 4. Duration Stream
    _player.durationStream.listen((dur) {
      final item = mediaItem.value;
      if (item != null && dur != null) {
        mediaItem.add(item.copyWith(duration: dur));
      }
    });
  }

  Future<void> _startPendingPlayback() async {
    if (_isStartingPendingPlayback || !_shouldPlayWhenReady || _player.playing) return;
    _isStartingPendingPlayback = true;
    try {
      for (var attempt = 0; attempt < 5; attempt++) {
        if (!_shouldPlayWhenReady || _player.playing) return;
        await _player.play();
        if (_player.playing) return;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } catch (e) {
      print('[AudioHandler] Delayed playback start failed: $e');
    } finally {
      _isStartingPendingPlayback = false;
    }
  }

  Future<void> _playSourceWhenReady() async {
    if (_player.processingState != ProcessingState.ready &&
        _player.processingState != ProcessingState.buffering) {
      await _player.processingStateStream
          .firstWhere(
            (state) => state == ProcessingState.ready || state == ProcessingState.buffering,
          )
          .timeout(const Duration(seconds: 10));
    }
    await _player.play();
  }

  Future<void> loadAndPlayTrack(Track track, {List<Track>? newQueue, int? index}) async {
    if (newQueue != null && newQueue.isNotEmpty) {
      _tracksQueue = List.from(newQueue);
      _currentIndex = (index ?? 0).clamp(0, _tracksQueue.length - 1);
    } else if (index != null && index >= 0 && index < _tracksQueue.length) {
      _currentIndex = index;
    } else {
      final foundIdx = _tracksQueue.indexWhere((t) => t.id == track.id);
      if (foundIdx != -1) {
        _currentIndex = foundIdx;
      } else if (_tracksQueue.isEmpty) {
        _tracksQueue = [track];
        _currentIndex = 0;
      }
    }

    var targetTrack = _tracksQueue[_currentIndex];
    final vId = targetTrack.videoId.isNotEmpty ? targetTrack.videoId : targetTrack.id;

    // Auto-resolve artist name if missing or generic
    final isGeneric = targetTrack.artistName.isEmpty ||
        targetTrack.artistName.toLowerCase() == 'unknown artist' ||
        targetTrack.artistName.toLowerCase() == 'artista sconosciuto' ||
        targetTrack.artistName.toLowerCase() == 'artista';
    if (isGeneric && vId.isNotEmpty) {
      try {
        final vid = await _api.yt.videos.get(vId).timeout(const Duration(seconds: 3));
        if (vid.author.isNotEmpty) {
          targetTrack = targetTrack.copyWith(artistName: AppConfig.sanitizeArtist(vid.author));
          _tracksQueue[_currentIndex] = targetTrack;
        }
      } catch (_) {}
    }

    await _storage.addToHistory(targetTrack);

    // Auto-resolve official studio square artwork if missing or YouTube video thumbnail
    if (targetTrack.coverUrl.isEmpty || targetTrack.coverUrl.contains('i.ytimg.com')) {
      _enrichTrackArtwork(targetTrack, _currentIndex);
    }

    // Update MediaItem for iOS Lock Screen & Android Notification & Windows SMTC
    final effectiveCover = targetTrack.effectiveCoverUrl;
    final item = MediaItem(
      id: targetTrack.id,
      album: targetTrack.albumName,
      title: targetTrack.title,
      artist: targetTrack.artistName,
      duration: Duration(milliseconds: targetTrack.durationMs),
      artUri: effectiveCover.isNotEmpty ? Uri.tryParse(effectiveCover) : null,
    );
    mediaItem.add(item);
    queue.add(_tracksQueue.map((t) {
      final tCover = t.effectiveCoverUrl;
      return MediaItem(
        id: t.id,
        album: t.albumName,
        title: t.title,
        artist: t.artistName,
        duration: Duration(milliseconds: t.durationMs),
        artUri: tCover.isNotEmpty ? Uri.tryParse(tCover) : null,
      );
    }).toList());

    _shouldPlayWhenReady = true;
    try {
      if (!_localProxy.isRunning) {
        await _localProxy.start();
      }
      final proxyUrl = _localProxy.getStreamUrl(vId);
      print('[AudioHandler] Playing stream via LocalStreamProxy: $proxyUrl');
      final audioSource = AudioSource.uri(
        Uri.parse(proxyUrl),
        tag: item,
      );
      await _player.setAudioSource(audioSource);
      await _playSourceWhenReady();
      _broadcastState();

      // Retry playback triggers if platform (e.g. Windows) was in Opening state
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_shouldPlayWhenReady && !_player.playing) {
          _player.play();
          _broadcastState();
        }
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_shouldPlayWhenReady && !_player.playing) {
          _player.play();
          _broadcastState();
        }
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (_shouldPlayWhenReady && !_player.playing) {
          _player.play();
          _broadcastState();
        }
      });

      // Prefetch radio mix if queue is single track
      if (_tracksQueue.length == 1) {
        _fetchAndAppendMix(targetTrack);
      }
    } catch (e) {
      print('[AudioHandler] LocalStreamProxy playback failed for ${targetTrack.title}: $e, trying direct API stream fallback');
      try {
        final streamUrl = await _api.resolveAudioStream(targetTrack);
        print('[AudioHandler] Playing direct stream for ${targetTrack.title}: $streamUrl');
        final fallbackSource = AudioSource.uri(
          Uri.parse(streamUrl),
          headers: {
            'User-Agent': 'com.google.android.youtube/19.29.35 (Linux; U; Android 11; US) gzip',
          },
          tag: item,
        );
        _shouldPlayWhenReady = true;
        await _player.setAudioSource(fallbackSource);
        await _playSourceWhenReady();
        _broadcastState();

        Future.delayed(const Duration(milliseconds: 300), () {
          if (_shouldPlayWhenReady && !_player.playing) {
            _player.play();
            _broadcastState();
          }
        });
        Future.delayed(const Duration(milliseconds: 800), () {
          if (_shouldPlayWhenReady && !_player.playing) {
            _player.play();
            _broadcastState();
          }
        });

        if (_tracksQueue.length == 1) {
          _fetchAndAppendMix(targetTrack);
        }
      } catch (err2) {
        print('[AudioHandler] All playback attempts failed for ${targetTrack.title}: $err2');
      }
    }
  }

  void _enrichTrackArtwork(Track track, int targetIndex) async {
    try {
      final result = await _api.resolveOfficialArtwork(track);
      if (result != null && result['coverUrl'] != null && result['coverUrl']!.isNotEmpty) {
        final newCover = result['coverUrl']!;
        final newAlbum = (result['album'] != null && result['album']!.isNotEmpty)
            ? result['album']!
            : track.albumName;
        final newArtist = (track.artistName.isEmpty ||
                track.artistName.toLowerCase() == 'artista' ||
                track.artistName.toLowerCase() == 'unknown artist') &&
            result['artist'] != null &&
            result['artist']!.isNotEmpty
            ? result['artist']!
            : track.artistName;

        if (targetIndex >= 0 && targetIndex < _tracksQueue.length && _tracksQueue[targetIndex].id == track.id) {
          final updated = _tracksQueue[targetIndex].copyWith(
            coverUrl: newCover,
            albumName: newAlbum.isNotEmpty ? newAlbum : _tracksQueue[targetIndex].albumName,
            artistName: newArtist,
          );
          _tracksQueue[targetIndex] = updated;

          if (_currentIndex == targetIndex) {
            final currentVal = mediaItem.value;
            final updatedItem = currentVal?.copyWith(
              album: newAlbum.isNotEmpty ? newAlbum : currentVal.album,
              artist: newArtist,
              artUri: Uri.tryParse(newCover),
            );
            if (updatedItem != null) {
              mediaItem.add(updatedItem);
            }
          }
        }
      }
    } catch (e) {
      print('[AudioHandler] Artwork enrichment error for ${track.title}: $e');
    }
  }

  Future<void> _fetchAndAppendMix(Track seed) async {
    try {
      final mixTracks = await _api.fetchMix(seed);
      if (mixTracks.isNotEmpty) {
        _tracksQueue.addAll(mixTracks);
        queue.add(_tracksQueue.map((t) {
          final tCover = t.effectiveCoverUrl;
          return MediaItem(
            id: t.id,
            album: t.albumName,
            title: t.title,
            artist: t.artistName,
            duration: Duration(milliseconds: t.durationMs),
            artUri: tCover.isNotEmpty ? Uri.tryParse(tCover) : null,
          );
        }).toList());
      }
    } catch (_) {}
  }

  @override
  Future<void> play() async {
    _shouldPlayWhenReady = true;
    await _player.play();
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    _shouldPlayWhenReady = false;
    await _player.pause();
    _broadcastState();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_tracksQueue.isEmpty) return;
    if (_currentIndex < _tracksQueue.length - 1) {
      _currentIndex++;
      await loadAndPlayTrack(_tracksQueue[_currentIndex], index: _currentIndex);
    } else if (_loopMode == LoopMode.all) {
      _currentIndex = 0;
      await loadAndPlayTrack(_tracksQueue[_currentIndex], index: _currentIndex);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 4) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      _currentIndex--;
      await loadAndPlayTrack(_tracksQueue[_currentIndex], index: _currentIndex);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  @override
  Future<void> stop() async {
    _shouldPlayWhenReady = false;
    await _player.stop();
    _broadcastState();
    return super.stop();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle && _tracksQueue.length > 1) {
      final current = currentTrack;
      _tracksQueue.shuffle();
      if (current != null) {
        _tracksQueue.removeWhere((t) => t.id == current.id);
        _tracksQueue.insert(0, current);
        _currentIndex = 0;
      }
    }
  }

  void cycleRepeatMode() {
    if (_loopMode == LoopMode.off) {
      _loopMode = LoopMode.all;
    } else if (_loopMode == LoopMode.all) {
      _loopMode = LoopMode.one;
    } else {
      _loopMode = LoopMode.off;
    }
    _player.setLoopMode(_loopMode);
  }

  LoopMode get loopMode => _loopMode;
  bool get isShuffle => _isShuffle;

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _tracksQueue.removeAt(oldIndex);
    _tracksQueue.insert(newIndex, item);
    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
  }

  void removeFromQueue(int index) {
    if (index >= 0 && index < _tracksQueue.length) {
      _tracksQueue.removeAt(index);
      if (_currentIndex >= _tracksQueue.length) {
        _currentIndex = _tracksQueue.length - 1;
      }
    }
  }

  void setQueue(List<Track> newQueue, int currentIndex) {
    if (newQueue.isNotEmpty) {
      _tracksQueue = List.from(newQueue);
      _currentIndex = currentIndex.clamp(0, _tracksQueue.length - 1);
      queue.add(_tracksQueue.map((t) => MediaItem(
        id: t.id,
        album: t.albumName,
        title: t.title,
        artist: t.artistName,
        duration: Duration(milliseconds: t.durationMs),
        artUri: Uri.tryParse(t.coverUrl),
      )).toList());
    }
  }

  void clearQueue() {
    final current = currentTrack;
    if (current != null) {
      _tracksQueue = [current];
      _currentIndex = 0;
    } else {
      _tracksQueue.clear();
      _currentIndex = 0;
    }
  }
}
