import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:palette_generator/palette_generator.dart';
import '../models/track.dart';
import '../models/lyrics.dart';
import '../services/audio_handler.dart';
import '../services/api_service.dart';

class PlayerState extends ChangeNotifier {
  final PreludedAudioHandler _audioHandler;
  final ApiService _api;

  Track? _currentTrack;
  List<Track> _queue = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(Duration.zero);
  Lyrics? _lyrics;
  bool _isLoadingLyrics = false;
  Color _ambientColor = const Color(0xFFFA2D48);

  StreamSubscription? _playbackStateSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _mediaItemSub;
  StreamSubscription? _positionSub;

  String? _lastLoadedTrackId;

  PlayerState(this._audioHandler, this._api) {
    _initListeners();
  }

  Track? get currentTrack => _currentTrack;
  List<Track> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  Duration get position => _position;
  Duration get duration => _duration;
  Lyrics? get lyrics => _lyrics;
  bool get isLoadingLyrics => _isLoadingLyrics;
  Color get ambientColor => _ambientColor;
  bool get isShuffle => _audioHandler.isShuffle;
  LoopMode get loopMode => _audioHandler.loopMode;

  void _initListeners() {
    // 1. Playback State
    _playbackStateSub = _audioHandler.playbackState.listen((state) {
      _isPlaying = state.playing;
      _isBuffering = state.processingState == AudioProcessingState.buffering ||
          state.processingState == AudioProcessingState.loading;
      _position = state.position;
      positionNotifier.value = state.position;
      _queue = _audioHandler.currentQueue;
      _currentIndex = _audioHandler.currentIndex;
      notifyListeners();
    });

    // 2. Direct playerStateStream backup listener
    _playerStateSub = _audioHandler.player.playerStateStream.listen((ps) {
      bool changed = false;
      if (_isPlaying != ps.playing) {
        _isPlaying = ps.playing;
        changed = true;
      }
      final buffering = ps.processingState == ProcessingState.buffering ||
          ps.processingState == ProcessingState.loading;
      if (_isBuffering != buffering) {
        _isBuffering = buffering;
        changed = true;
      }
      if (changed) {
        notifyListeners();
      }
    });

    // 3. MediaItem (Track Metadata)
    _mediaItemSub = _audioHandler.mediaItem.listen((item) {
      if (item != null) {
        final trackIdChanged = _lastLoadedTrackId != item.id;
        _lastLoadedTrackId = item.id;
        _duration = item.duration ?? Duration.zero;
        final matching = _audioHandler.currentTrack;
        if (matching != null && matching.id == item.id) {
          _currentTrack = matching.copyWith(
            coverUrl: matching.effectiveCoverUrl,
            albumName: matching.albumName.isNotEmpty ? matching.albumName : _currentTrack?.albumName,
            artistName: matching.artistName.isNotEmpty ? matching.artistName : _currentTrack?.artistName,
          );
        } else {
          final art = item.artUri?.toString() ?? '';
          final validArt = art.isNotEmpty && !art.contains('resources.tidal.com')
              ? art
              : (_currentTrack?.effectiveCoverUrl ?? 'https://i.ytimg.com/vi/${item.id}/hqdefault.jpg');
          _currentTrack = Track(
            id: item.id,
            videoId: item.id,
            title: item.title,
            artistName: item.artist ?? 'Artist',
            albumName: item.album ?? '',
            coverUrl: validArt,
            durationMs: item.duration?.inMilliseconds ?? 210000,
          );
        }
        _updateAmbientColor(_currentTrack?.coverUrl);
        if (trackIdChanged) {
          fetchLyricsForCurrentTrack();
        }
        notifyListeners();
      }
    });

    // 3. Position Updates (Updates ValueNotifier without triggering expensive tree-wide rebuilds)
    _positionSub = _audioHandler.player.positionStream.listen((pos) {
      _position = pos;
      positionNotifier.value = pos;
    });
  }

  Future<void> _updateAmbientColor([String? explicitCover]) async {
    final cover = explicitCover ?? _currentTrack?.effectiveCoverUrl;
    if (cover == null || cover.isEmpty) return;

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(cover),
        maximumColorCount: 16,
      );

      _ambientColor = palette.dominantColor?.color ??
          palette.mutedColor?.color ??
          palette.vibrantColor?.color ??
          const Color(0xFFFA2D48);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> playTrack(Track track, {List<Track>? newQueue, int index = 0}) async {
    final effectiveTrack = track.copyWith(
      coverUrl: track.effectiveCoverUrl,
    );
    _currentTrack = effectiveTrack;
    if (newQueue != null) {
      _queue = newQueue.map((t) => t.copyWith(coverUrl: t.effectiveCoverUrl)).toList();
      _currentIndex = index;
    }
    _isPlaying = true;
    _isBuffering = true;
    notifyListeners();
    await _audioHandler.loadAndPlayTrack(effectiveTrack, newQueue: _queue, index: index);
  }

  Future<int> startMix(Track track) async {
    final mix = await _api.fetchMix(track);
    if (mix.isNotEmpty) {
      final fullQueue = [track, ...mix];
      _queue = fullQueue;
      _currentIndex = 0;
      _currentTrack = track;
      _audioHandler.setQueue(fullQueue, 0);
      notifyListeners();
      return mix.length;
    }
    return 0;
  }

  Future<void> togglePlay() async {
    final nextPlaying = !_isPlaying;
    _isPlaying = nextPlaying;
    notifyListeners();
    if (nextPlaying) {
      await _audioHandler.play();
    } else {
      await _audioHandler.pause();
    }
  }

  Future<void> nextTrack() async {
    await _audioHandler.skipToNext();
    final cur = _audioHandler.currentTrack;
    if (cur != null) {
      _currentTrack = cur;
      _currentIndex = _audioHandler.currentIndex;
      _queue = _audioHandler.currentQueue;
      notifyListeners();
    }
  }

  Future<void> previousTrack() async {
    await _audioHandler.skipToPrevious();
    final cur = _audioHandler.currentTrack;
    if (cur != null) {
      _currentTrack = cur;
      _currentIndex = _audioHandler.currentIndex;
      _queue = _audioHandler.currentQueue;
      notifyListeners();
    }
  }
  Future<void> seek(Duration pos) async {
    _position = pos;
    positionNotifier.value = pos;
    await _audioHandler.seek(pos);
  }

  void toggleShuffle() {
    _audioHandler.toggleShuffle();
    _queue = _audioHandler.currentQueue;
    _currentIndex = _audioHandler.currentIndex;
    notifyListeners();
  }

  void cycleRepeat() {
    _audioHandler.cycleRepeatMode();
    notifyListeners();
  }

  Future<void> fetchLyricsForCurrentTrack() async {
    if (_currentTrack == null) return;
    _isLoadingLyrics = true;
    _lyrics = null;
    notifyListeners();

    try {
      _lyrics = await _api.fetchLyrics(_currentTrack!);
    } catch (_) {}
    _isLoadingLyrics = false;
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    _audioHandler.reorderQueue(oldIndex, newIndex);
    _queue = _audioHandler.currentQueue;
    _currentIndex = _audioHandler.currentIndex;
    notifyListeners();
  }

  void removeFromQueue(int index) {
    _audioHandler.removeFromQueue(index);
    _queue = _audioHandler.currentQueue;
    _currentIndex = _audioHandler.currentIndex;
    notifyListeners();
  }

  void clearQueue() {
    _audioHandler.clearQueue();
    _queue = _audioHandler.currentQueue;
    _currentIndex = _audioHandler.currentIndex;
    notifyListeners();
  }

  @override
  void dispose() {
    _playbackStateSub?.cancel();
    _playerStateSub?.cancel();
    _mediaItemSub?.cancel();
    _positionSub?.cancel();
    positionNotifier.dispose();
    super.dispose();
  }
}
