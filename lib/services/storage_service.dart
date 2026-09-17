import 'dart:convert';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../models/user.dart';
import '../config/app_config.dart';

class StorageService {
  static const _keyLiked = 'preluded_liked_songs';
  static const _keyPlaylists = 'preluded_playlists';
  static const _keyHistory = 'preluded_history';
  static const _keyCookie = 'preluded_ytm_cookie';
  static const _keyBackendUrl = 'preluded_backend_url';
  static const _keyGoogleUser = 'preluded_google_user';
  static const _keyFollowedArtists = 'preluded_followed_artists';
  static const _keySavedAlbums = 'preluded_saved_albums';

  final SharedPreferences _prefs;
  final ValueNotifier<int> historyVersion = ValueNotifier(0);
  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // --- Google User Account ---
  GoogleUser? getGoogleUser() {
    final raw = _prefs.getString(_keyGoogleUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      return GoogleUser.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> setGoogleUser(GoogleUser? user) async {
    if (user == null) {
      await _prefs.remove(_keyGoogleUser);
    } else {
      await _prefs.setString(_keyGoogleUser, jsonEncode(user.toJson()));
      if (user.cookie != null && user.cookie!.isNotEmpty) {
        await setYtmCookie(user.cookie);
      }
    }
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

  Future<void> saveHistory(List<Track> list) async {
    final encoded = list.map((t) => jsonEncode(t.toJson())).toList();
    await _prefs.setStringList(_keyHistory, encoded);
    historyVersion.value++;
  }

  Future<void> addToHistory(Track track) async {
    final list = getHistory();
    list.removeWhere((t) => t.id == track.id || t.videoId == track.id);
    list.insert(0, track);
    if (list.length > 100) {
      list.removeRange(100, list.length);
    }
    await saveHistory(list);
  }

  Future<void> clearHistory() async {
    await _prefs.remove(_keyHistory);
    historyVersion.value++;
  }

  Future<void> clearAllCache() async {
    await _prefs.clear();
    historyVersion.value++;
  }

  // --- Followed Artists ---
  List<String> getFollowedArtistIds() {
    return _prefs.getStringList(_keyFollowedArtists) ?? [];
  }

  bool isArtistFollowed(String artistId) {
    if (artistId.isEmpty) return false;
    final list = getFollowedArtistIds();
    return list.contains(artistId);
  }

  Future<bool> toggleFollowArtist(String artistId) async {
    if (artistId.isEmpty) return false;
    final list = List<String>.from(getFollowedArtistIds());
    bool isNowFollowed;
    if (list.contains(artistId)) {
      list.remove(artistId);
      isNowFollowed = false;
    } else {
      list.add(artistId);
      isNowFollowed = true;
    }
    await _prefs.setStringList(_keyFollowedArtists, list);
    return isNowFollowed;
  }

  // --- Saved Albums ---
  List<String> getSavedAlbumIds() {
    return _prefs.getStringList(_keySavedAlbums) ?? [];
  }

  bool isAlbumSaved(String albumId) {
    if (albumId.isEmpty) return false;
    final list = getSavedAlbumIds();
    return list.contains(albumId);
  }

  Future<bool> toggleSaveAlbum(String albumId) async {
    if (albumId.isEmpty) return false;
    final list = List<String>.from(getSavedAlbumIds());
    bool isNowSaved;
    if (list.contains(albumId)) {
      list.remove(albumId);
      isNowSaved = false;
    } else {
      list.add(albumId);
      isNowSaved = true;
    }
    await _prefs.setStringList(_keySavedAlbums, list);
    return isNowSaved;
  }
}
