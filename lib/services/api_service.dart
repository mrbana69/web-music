import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../models/lyrics.dart';
import 'storage_service.dart';

class ApiService {
  final StorageService _storage;
  final http.Client _client;

  ApiService(this._storage, [http.Client? client]) : _client = client ?? http.Client();

  String get baseUrl => _storage.getBackendUrl();

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final cookie = _storage.getYtmCookie();
    if (cookie != null && cookie.isNotEmpty) {
      headers['X-YTM-Cookie'] = cookie;
    }
    return headers;
  }

  // --- 1. Quick Picks (Scelte Rapide) ---
  Future<List<Track>> fetchQuickPicks({int limit = 20}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/quick-picks?limit=$limit');
      final res = await _client.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final items = (data['items'] ?? data['data']?['items'] ?? []) as List;
        return items.map((i) => Track.fromJson(Map<String, dynamic>.from(i))).toList();
      }
    } catch (_) {}
    return [];
  }

  // --- 2. Home Feed Shelves ---
  Future<Map<String, List<Track>>> fetchHomeSections() async {
    final sections = <String, List<Track>>{};
    try {
      final uri = Uri.parse('$baseUrl/api/home');
      final res = await _client.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawSections = (data['sections'] ?? data['data'] ?? []) as List;
        for (final sec in rawSections) {
          final title = sec['title']?.toString() ?? 'Consigliati';
          final items = (sec['items'] as List? ?? [])
              .map((i) => Track.fromJson(Map<String, dynamic>.from(i)))
              .toList();
          if (items.isNotEmpty) {
            sections[title] = items;
          }
        }
      }
    } catch (_) {}
    return sections;
  }

  // --- 3. Search ---
  Future<Map<String, dynamic>> search(String query, {String filter = 'all', int limit = 25}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/search?s=${Uri.encodeComponent(query)}&type=$filter&limit=$limit');
      final res = await _client.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawItems = (data['data']?['items'] ?? data['items'] ?? []) as List;
        final tracks = rawItems.map((i) => Track.fromJson(Map<String, dynamic>.from(i))).toList();

        final rawArtists = (data['data']?['artists'] ?? data['artists'] ?? []) as List;
        final artists = rawArtists.map((a) => Artist.fromJson(Map<String, dynamic>.from(a))).toList();

        final rawAlbums = (data['data']?['albums'] ?? data['albums'] ?? []) as List;
        final albums = rawAlbums.map((al) => Album.fromJson(Map<String, dynamic>.from(al))).toList();

        return {
          'tracks': tracks,
          'artists': artists,
          'albums': albums,
        };
      }
    } catch (_) {}
    return {'tracks': <Track>[], 'artists': <Artist>[], 'albums': <Album>[]};
  }

  // --- 4. Resolve Stream URL ---
  Future<String> resolveAudioStream(Track track) async {
    final vId = track.videoId.isNotEmpty ? track.videoId : track.id;
    // Primary endpoint: fast stream.mp4 proxy with Apple AVPlayer / AAC optimization
    return '$baseUrl/api/stream.mp4?id=${Uri.encodeComponent(vId)}';
  }

  // --- 5. Lyrics ---
  Future<Lyrics?> fetchLyrics(Track track) async {
    try {
      final vId = track.videoId.isNotEmpty ? track.videoId : track.id;
      final uri = Uri.parse(
        '$baseUrl/api/lyrics?id=${Uri.encodeComponent(vId)}&title=${Uri.encodeComponent(track.title)}&artist=${Uri.encodeComponent(track.artistName)}&duration=${track.durationMs ~/ 1000}',
      );
      final res = await _client.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final synced = data['syncedLyrics']?.toString() ?? data['lrc']?.toString() ?? '';
        final plain = data['plainLyrics']?.toString() ?? data['lyrics']?.toString() ?? '';
        final translation = data['translation']?.toString();

        if (synced.isNotEmpty) {
          return Lyrics.parse(rawLrc: synced, translationText: translation);
        } else if (plain.isNotEmpty) {
          return Lyrics(plainText: plain, translation: translation, isSynced: false);
        }
      }
    } catch (_) {}
    return null;
  }

  // --- 6. Track Radio Mix ---
  Future<List<Track>> fetchMix(Track track) async {
    try {
      final vId = track.videoId.isNotEmpty ? track.videoId : track.id;
      final uri = Uri.parse(
        '$baseUrl/api/mix?id=${Uri.encodeComponent(vId)}&title=${Uri.encodeComponent(track.title)}&artist=${Uri.encodeComponent(track.artistName)}',
      );
      final res = await _client.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final items = (data['items'] ?? data['data']?['items'] ?? []) as List;
        return items
            .map((i) => Track.fromJson(Map<String, dynamic>.from(i['item'] ?? i)))
            .where((t) => t.id != track.id)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // --- 7. Artist Details ---
  Future<Artist?> fetchArtist(String artistId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/artist?id=${Uri.encodeComponent(artistId)}');
      final res = await _client.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return Artist.fromJson(Map<String, dynamic>.from(data['artist'] ?? data));
      }
    } catch (_) {}
    return null;
  }

  // --- 8. Album Details ---
  Future<Album?> fetchAlbum(String albumId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/album?id=${Uri.encodeComponent(albumId)}');
      final res = await _client.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return Album.fromJson(Map<String, dynamic>.from(data['album'] ?? data));
      }
    } catch (_) {}
    return null;
  }
}
