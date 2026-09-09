import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import 'api_service.dart';
import 'storage_service.dart';

Future<AudioHandler> initAudioService(ApiService apiService, StorageService storageService) async {
  return await AudioService.init(
    builder: () => PreludedAudioHandler(apiService, storageService),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.preluded.music.channel.audio',
      androidNotificationChannelName: 'Preluded Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
}

class PreludedAudioHandler extends BaseAudioHandler with SeekHandler {
  final ApiService _api;
  final StorageService _storage;
  final AudioPlayer _player = AudioPlayer();

  List<Track> _tracksQueue = [];
  int _currentIndex = 0;
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;

  PreludedAudioHandler(this._api, this._storage) {
    _initPlayerListeners();
  }

  AudioPlayer get player => _player;
  List<Track> get currentQueue => _tracksQueue;
  int get currentIndex => _currentIndex;
  Track? get currentTrack => (_currentIndex >= 0 && _currentIndex < _tracksQueue.length)
      ? _tracksQueue[_currentIndex]
      : null;

  void _initPlayerListeners() {
    // 1. Playback Events
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
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
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
      ));
    });

    // 2. Track Completion -> Auto Next
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_loopMode == LoopMode.one) {
          _player.seek(Duration.zero);
          _player.play();
        } else {
          skipToNext();
        }
      }
    });

    // 3. Duration Stream
    _player.durationStream.listen((dur) {
      final item = mediaItem.value;
      if (item != null && dur != null) {
        mediaItem.add(item.copyWith(duration: dur));
      }
    });
  }

  Future<void> loadAndPlayTrack(Track track, {List<Track>? newQueue, int index = 0}) async {
    if (newQueue != null && newQueue.isNotEmpty) {
      _tracksQueue = List.from(newQueue);
      _currentIndex = index.clamp(0, _tracksQueue.length - 1);
    } else {
      _tracksQueue = [track];
      _currentIndex = 0;
    }

    final targetTrack = _tracksQueue[_currentIndex];
    await _storage.addToHistory(targetTrack);

    // Update MediaItem for iOS Lock Screen & Dynamic Island
    final item = MediaItem(
      id: targetTrack.id,
      album: targetTrack.albumName,
      title: targetTrack.title,
      artist: targetTrack.artistName,
      duration: Duration(milliseconds: targetTrack.durationMs),
      artUri: Uri.parse(targetTrack.coverUrl),
    );
    mediaItem.add(item);
    queue.add(_tracksQueue.map((t) => MediaItem(
      id: t.id,
      album: t.albumName,
      title: t.title,
      artist: t.artistName,
      duration: Duration(milliseconds: t.durationMs),
      artUri: Uri.parse(t.coverUrl),
    )).toList());

    try {
      final streamUrl = await _api.resolveAudioStream(targetTrack);
      await _player.setUrl(streamUrl);
      await _player.play();

      // Prefetch radio mix if queue is single track
      if (_tracksQueue.length == 1) {
        _fetchAndAppendMix(targetTrack);
      }
    } catch (e) {
      print('Audio playback error: $e');
    }
  }

  Future<void> _fetchAndAppendMix(Track seed) async {
    try {
      final mixTracks = await _api.fetchMix(seed);
      if (mixTracks.isNotEmpty) {
        _tracksQueue.addAll(mixTracks);
        queue.add(_tracksQueue.map((t) => MediaItem(
          id: t.id,
          album: t.albumName,
          title: t.title,
          artist: t.artistName,
          duration: Duration(milliseconds: t.durationMs),
          artUri: Uri.parse(t.coverUrl),
        )).toList());
      }
    } catch (_) {}
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_tracksQueue.isEmpty) return;
    if (_currentIndex < _tracksQueue.length - 1) {
      _currentIndex++;
      await loadAndPlayTrack(_tracksQueue[_currentIndex]);
    } else if (_loopMode == LoopMode.all) {
      _currentIndex = 0;
      await loadAndPlayTrack(_tracksQueue[_currentIndex]);
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
      await loadAndPlayTrack(_tracksQueue[_currentIndex]);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
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
}
