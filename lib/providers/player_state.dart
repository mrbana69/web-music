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
  Lyrics? _lyrics;
  bool _isLoadingLyrics = false;
  Color _ambientColor = const Color(0xFFFA2D48);

  StreamSubscription? _playbackStateSub;
  StreamSubscription? _mediaItemSub;
  StreamSubscription? _positionSub;

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
      _queue = _audioHandler.currentQueue;
      _currentIndex = _audioHandler.currentIndex;
      notifyListeners();
    });

    // 2. MediaItem (Track Metadata)
    _mediaItemSub = _audioHandler.mediaItem.listen((item) {
      if (item != null) {
        _duration = item.duration ?? Duration.zero;
        final matching = _audioHandler.currentTrack;
        if (matching != null && matching.id == item.id) {
          _currentTrack = matching;
        } else {
          _currentTrack = Track(
            id: item.id,
            videoId: item.id,
            title: item.title,
            artistName: item.artist ?? 'Artist',
            albumName: item.album ?? '',
            coverUrl: item.artUri?.toString() ?? '',
            durationMs: item.duration?.inMilliseconds ?? 210000,
          );
        }
        _updateAmbientColor(_currentTrack?.coverUrl);
        fetchLyricsForCurrentTrack();
        notifyListeners();
      }
    });

    // 3. Position Updates
    _positionSub = _audioHandler.player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });
  }

  Future<void> _updateAmbientColor(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        size: const Size(100, 100),
        maximumColorCount: 8,
      );
      _ambientColor = palette.dominantColor?.color ??
          palette.vibrantColor?.color ??
          const Color(0xFFFA2D48);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> playTrack(Track track, {List<Track>? newQueue, int index = 0}) async {
    _currentTrack = track;
    if (newQueue != null) {
      _queue = newQueue;
      _currentIndex = index;
    }
    notifyListeners();
    await _audioHandler.loadAndPlayTrack(track, newQueue: newQueue, index: index);
  }

  Future<void> togglePlay() async {
    if (_isPlaying) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> nextTrack() async => await _audioHandler.skipToNext();
  Future<void> previousTrack() async => await _audioHandler.skipToPrevious();
  Future<void> seek(Duration pos) async => await _audioHandler.seek(pos);

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

  @override
  void dispose() {
    _playbackStateSub?.cancel();
    _mediaItemSub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }
}
