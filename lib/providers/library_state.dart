import 'package:flutter/material.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../services/storage_service.dart';

class LibraryState extends ChangeNotifier {
  final StorageService _storage;

  List<Track> _likedTracks = [];
  List<Playlist> _playlists = [];
  List<Track> _history = [];
  String? _ytmCookie;
  String _backendUrl = '';

  LibraryState(this._storage) {
    _loadInitialData();
  }

  List<Track> get likedTracks => _likedTracks;
  List<Playlist> get playlists => _playlists;
  List<Track> get history => _history;
  String? get ytmCookie => _ytmCookie;
  String get backendUrl => _backendUrl;

  void _loadInitialData() {
    _likedTracks = _storage.getLikedSongs();
    _playlists = _storage.getPlaylists();
    _history = _storage.getHistory();
    _ytmCookie = _storage.getYtmCookie();
    _backendUrl = _storage.getBackendUrl();
    notifyListeners();
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

  Future<void> saveYtmCookie(String? cookie) async {
    await _storage.setYtmCookie(cookie);
    _ytmCookie = cookie;
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
}
