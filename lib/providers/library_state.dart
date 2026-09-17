import 'package:flutter/material.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../models/user.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';

class LibraryState extends ChangeNotifier {
  final StorageService _storage;

  List<Track> _likedTracks = [];
  List<Playlist> _playlists = [];
  List<Track> _history = [];
  String? _ytmCookie;
  String _backendUrl = '';
  GoogleUser? _googleUser;
  bool _isSyncing = false;

  List<String> _followedArtists = [];
  List<String> _savedAlbums = [];

  LibraryState(this._storage) {
    _loadInitialData();
    _storage.historyVersion.addListener(() {
      _history = _storage.getHistory();
      notifyListeners();
    });
  }

  List<Track> get likedTracks => _likedTracks;
  List<Playlist> get playlists => _playlists;
  List<Track> get history => _history;
  List<String> get followedArtists => _followedArtists;
  List<String> get savedAlbums => _savedAlbums;
  String? get ytmCookie => _ytmCookie;
  String get backendUrl => _backendUrl;
  GoogleUser? get googleUser => _googleUser;
  bool get isGoogleLoggedIn => _googleUser != null;
  bool get isSyncing => _isSyncing;

  void _loadInitialData() {
    _likedTracks = _storage.getLikedSongs();
    _playlists = _storage.getPlaylists();
    _history = _storage.getHistory();
    _followedArtists = _storage.getFollowedArtistIds();
    _savedAlbums = _storage.getSavedAlbumIds();
    _ytmCookie = _storage.getYtmCookie();
    _backendUrl = _storage.getBackendUrl();
    _googleUser = _storage.getGoogleUser();
    notifyListeners();
  }

  bool isArtistFollowed(String artistId) {
    return _followedArtists.contains(artistId);
  }

  Future<bool> toggleFollowArtist(String artistId) async {
    final res = await _storage.toggleFollowArtist(artistId);
    _followedArtists = _storage.getFollowedArtistIds();
    notifyListeners();
    return res;
  }

  bool isAlbumSaved(String albumId) {
    return _savedAlbums.contains(albumId);
  }

  Future<bool> toggleSaveAlbum(String albumId) async {
    final res = await _storage.toggleSaveAlbum(albumId);
    _savedAlbums = _storage.getSavedAlbumIds();
    notifyListeners();
    return res;
  }

  bool isLiked(String trackId) {
    return _likedTracks.any((t) => t.id == trackId || t.videoId == trackId);
  }

  Future<bool> toggleLike(Track track) async {
    final isNowLiked = await _storage.toggleLike(track);
    _likedTracks = _storage.getLikedSongs();
    notifyListeners();
    return isNowLiked;
  }

  Future<Playlist> createPlaylist(String title, {String subtitle = ''}) async {
    final pl = await _storage.createPlaylist(title, subtitle: subtitle);
    _playlists = _storage.getPlaylists();
    notifyListeners();
    return pl;
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _storage.deletePlaylist(playlistId);
    _playlists = _storage.getPlaylists();
    notifyListeners();
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    await _storage.addTrackToPlaylist(playlistId, track);
    _playlists = _storage.getPlaylists();
    notifyListeners();
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    await _storage.removeTrackFromPlaylist(playlistId, trackId);
    _playlists = _storage.getPlaylists();
    notifyListeners();
  }

  // --- Google Account Management ---
  Future<void> loginWithGoogle(GoogleUser user) async {
    await _storage.setGoogleUser(user);
    _googleUser = user;
    if (user.cookie != null && user.cookie!.isNotEmpty) {
      _ytmCookie = user.cookie;
    }
    notifyListeners();
  }

  Future<void> logoutGoogle() async {
    await _storage.setGoogleUser(null);
    await _storage.setYtmCookie(null);
    _googleUser = null;
    _ytmCookie = null;
    notifyListeners();
  }

  Future<bool> syncGoogleAccount(ApiService api) async {
    if (_googleUser == null && _ytmCookie == null) return false;
    _isSyncing = true;
    notifyListeners();

    try {
      final result = await api.syncGoogleLibrary(
        token: _googleUser?.token,
        cookie: _googleUser?.cookie ?? _ytmCookie,
      );

      final fetchedUser = result['user'] as GoogleUser?;
      if (fetchedUser != null) {
        _googleUser = fetchedUser;
        await _storage.setGoogleUser(fetchedUser);
      }

      final syncedLikes = result['likedSongs'] as List<Track>? ?? [];
      final syncedPlaylists = result['playlists'] as List<Playlist>? ?? [];

      if (syncedLikes.isNotEmpty) {
        final existingIds = _likedTracks.map((t) => t.id).toSet();
        for (final song in syncedLikes) {
          if (!existingIds.contains(song.id)) {
            _likedTracks.add(song);
          }
        }
        await _storage.saveLikedSongs(_likedTracks);
      }

      if (syncedPlaylists.isNotEmpty) {
        final existingPlIds = _playlists.map((p) => p.id).toSet();
        for (final pl in syncedPlaylists) {
          if (!existingPlIds.contains(pl.id)) {
            _playlists.add(pl);
          }
        }
        await _storage.savePlaylists(_playlists);
      }

      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('syncGoogleAccount error: $e');
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> saveYtmCookie(String? cookie) async {
    await _storage.setYtmCookie(cookie);
    _ytmCookie = cookie;
    if (cookie != null && cookie.isNotEmpty && _googleUser != null) {
      _googleUser = _googleUser!.copyWith(cookie: cookie);
      await _storage.setGoogleUser(_googleUser);
    }
    notifyListeners();
  }

  Future<void> updateBackendUrl(String url) async {
    await _storage.setBackendUrl(url);
    _backendUrl = url;
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _storage.clearHistory();
    _history = [];
    notifyListeners();
  }

  Future<void> clearAllCache() async {
    await _storage.clearAllCache();
    _loadInitialData();
  }

  bool _isRepairingHistory = false;
  Future<void> repairHistoryArtists(ApiService api) async {
    if (_isRepairingHistory || _history.isEmpty) return;
    _isRepairingHistory = true;
    try {
      bool changed = false;
      final repaired = <Track>[];
      for (final t in _history) {
        final isGeneric = t.artistName.isEmpty ||
            t.artistName.toLowerCase() == 'unknown artist' ||
            t.artistName.toLowerCase() == 'artista sconosciuto' ||
            t.artistName.toLowerCase() == 'artista' ||
            t.artistName.toLowerCase() == 'artist';
        if (isGeneric) {
          try {
            final vId = t.videoId.isNotEmpty ? t.videoId : t.id;
            final vid = await api.yt.videos.get(vId).timeout(const Duration(seconds: 4));
            if (vid.author.isNotEmpty) {
              repaired.add(t.copyWith(artistName: AppConfig.sanitizeArtist(vid.author)));
              changed = true;
              continue;
            }
          } catch (_) {}
        }
        repaired.add(t);
      }
      if (changed) {
        _history = repaired;
        await _storage.saveHistory(repaired);
        notifyListeners();
      }
    } finally {
      _isRepairingHistory = false;
    }
  }
}
