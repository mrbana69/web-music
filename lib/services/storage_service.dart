import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../config/app_config.dart';

class StorageService {
  static const _keyLiked = 'preluded_liked_songs';
  static const _keyPlaylists = 'preluded_playlists';
  static const _keyHistory = 'preluded_history';
  static const _keyCookie = 'preluded_ytm_cookie';
  static const _keyBackendUrl = 'preluded_backend_url';

  final SharedPreferences _prefs;
  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // --- Backend URL ---
  String getBackendUrl() {
    return _prefs.getString(_keyBackendUrl) ?? AppConfig.defaultBaseUrl;
  }

  Future<void> setBackendUrl(String url) async {
    await _prefs.setString(_keyBackendUrl, url.trim());
  }

  // --- YouTube Music Session Cookie ---
  String? getYtmCookie() {
    return _prefs.getString(_keyCookie);
  }

  Future<void> setYtmCookie(String? cookie) async {
    if (cookie == null || cookie.isEmpty) {
      await _prefs.remove(_keyCookie);
    } else {
      await _prefs.setString(_keyCookie, cookie.trim());
    }
  }

  // --- Liked Songs ---
  List<Track> getLikedSongs() {
    final raw = _prefs.getStringList(_keyLiked) ?? [];
    return raw
        .map((s) {
          try {
            return Track.fromJson(jsonDecode(s));
          } catch (_) {
            return null;
          }
        })
        .whereType<Track>()
        .toList();
  }

  Future<void> saveLikedSongs(List<Track> list) async {
    final encoded = list.map((t) => jsonEncode(t.toJson())).toList();
    await _prefs.setStringList(_keyLiked, encoded);
  }

  bool isLiked(String trackId) {
    final list = getLikedSongs();
    return list.any((t) => t.id == trackId || t.videoId == trackId);
  }

  Future<bool> toggleLike(Track track) async {
    final list = getLikedSongs();
    final index = list.indexWhere((t) => t.id == track.id || t.videoId == track.id);
    bool isNowLiked;
    if (index >= 0) {
      list.removeAt(index);
      isNowLiked = false;
    } else {
      list.insert(0, track.copyWith(isLiked: true));
      isNowLiked = true;
    }
    await saveLikedSongs(list);
    return isNowLiked;
  }

  // --- Playlists ---
  List<Playlist> getPlaylists() {
    final raw = _prefs.getStringList(_keyPlaylists) ?? [];
    return raw
        .map((s) {
          try {
            return Playlist.fromJson(jsonDecode(s));
          } catch (_) {
            return null;
          }
        })
        .whereType<Playlist>()
        .toList();
  }

  Future<void> savePlaylists(List<Playlist> list) async {
    final encoded = list.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList(_keyPlaylists, encoded);
  }

  Future<Playlist> createPlaylist(String title, {String subtitle = ''}) async {
    final list = getPlaylists();
    final newPl = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      subtitle: subtitle.trim(),
      tracks: [],
    );
    list.insert(0, newPl);
    await savePlaylists(list);
    return newPl;
  }

  Future<void> deletePlaylist(String playlistId) async {
    final list = getPlaylists();
    list.removeWhere((p) => p.id == playlistId);
    await savePlaylists(list);
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    final list = getPlaylists();
    final index = list.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final pl = list[index];
      if (!pl.tracks.any((t) => t.id == track.id)) {
        final updatedTracks = List<Track>.from(pl.tracks)..add(track);
        list[index] = pl.copyWith(
          tracks: updatedTracks,
          coverUrl: pl.coverUrl.isEmpty ? track.coverUrl : pl.coverUrl,
          subtitle: '${updatedTracks.length} brani',
        );
        await savePlaylists(list);
      }
    }
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final list = getPlaylists();
    final index = list.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final pl = list[index];
      final updatedTracks = List<Track>.from(pl.tracks)..removeWhere((t) => t.id == trackId);
      list[index] = pl.copyWith(
        tracks: updatedTracks,
        subtitle: '${updatedTracks.length} brani',
      );
      await savePlaylists(list);
    }
  }

  // --- Listening History ---
  List<Track> getHistory() {
    final raw = _prefs.getStringList(_keyHistory) ?? [];
    return raw
        .map((s) {
          try {
            return Track.fromJson(jsonDecode(s));
          } catch (_) {
            return null;
          }
        })
        .whereType<Track>()
        .toList();
  }

  Future<void> addToHistory(Track track) async {
    final list = getHistory();
    list.removeWhere((t) => t.id == track.id || t.videoId == track.id);
    list.insert(0, track);
    if (list.length > 100) {
      list.removeRange(100, list.length);
    }
    final encoded = list.map((t) => jsonEncode(t.toJson())).toList();
    await _prefs.setStringList(_keyHistory, encoded);
  }

  Future<void> clearHistory() async {
    await _prefs.remove(_keyHistory);
  }

  Future<void> clearAllCache() async {
    await _prefs.clear();
  }
}
