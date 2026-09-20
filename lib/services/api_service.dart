import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;
import '../models/track.dart';
import '../models/artist.dart';
import '../models/album.dart';
import '../models/lyrics.dart';
import '../models/playlist.dart';
import '../models/user.dart';
import '../config/app_config.dart';
import 'storage_service.dart';

class ApiService {
  final StorageService _storage;
  final http.Client _client;
  final YoutubeExplode _yt;

  static const String _innertubeEndpoint = 'https://music.youtube.com/youtubei/v1';

  ApiService(this._storage, [http.Client? client, YoutubeExplode? yt])
      : _client = client ?? http.Client(),
        _yt = yt ?? YoutubeExplode();

  String get baseUrl => _storage.getBackendUrl();
  YoutubeExplode get yt => _yt;

  // --- YouTube Music Innertube Headers ---
  Map<String, String> _buildInnertubeHeaders([String? customCookie]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
      'Accept': '*/*',
      'Accept-Language': 'it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7',
      'Origin': 'https://music.youtube.com',
      'Referer': 'https://music.youtube.com/',
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'same-origin',
      'X-Origin': 'https://music.youtube.com',
      'X-Goog-AuthUser': '0',
      'X-YouTube-Client-Name': '67',
      'X-YouTube-Client-Version': '1.20241101.01.00',
    };

    var cookie = (customCookie != null && customCookie.isNotEmpty) ? customCookie : _storage.getYtmCookie();
    if (cookie != null && cookie.isNotEmpty) {
      final trimmed = cookie.trim();
      if (!trimmed.contains('=') && !trimmed.contains(';')) {
        headers['Cookie'] = 'SAPISID=$trimmed; __Secure-3PAPISID=$trimmed; __Secure-1PAPISID=$trimmed';
      } else {
        headers['Cookie'] = trimmed;
      }
      final authHeader = _generateSapisidHash(cookie);
      if (authHeader != null) {
        headers['Authorization'] = authHeader;
      }
    }
    return headers;
  }

  List<Map<String, dynamic>> _findNodes(dynamic node, String key) {
    final results = <Map<String, dynamic>>[];
    void search(dynamic current) {
      if (current is Map) {
        if (current.containsKey(key) && current[key] is Map) {
          results.add(Map<String, dynamic>.from(current[key]));
        }
        for (final val in current.values) {
          search(val);
        }
      } else if (current is List) {
        for (final item in current) {
          search(item);
        }
      }
    }
    search(node);
    return results;
  }

  String _extractLargestThumbnail(dynamic node) {
    if (node == null) return '';
    final foundUrls = <String>[];
    void search(dynamic current) {
      if (current is Map) {
        if (current.containsKey('thumbnails') && current['thumbnails'] is List) {
          for (final t in current['thumbnails'] as List) {
            final u = (t as Map)['url']?.toString();
            if (u != null && u.isNotEmpty && !u.contains('avatar')) {
              foundUrls.add(u);
            }
          }
        }
        for (final v in current.values) {
          search(v);
        }
      } else if (current is List) {
        for (final item in current) {
          search(item);
        }
      }
    }
    search(node);
    return foundUrls.isNotEmpty ? foundUrls.last : '';
  }

  String? _generateSapisidHash(String cookieString, [String origin = 'https://music.youtube.com']) {
    try {
      String? sapisid;
      final trimmed = cookieString.trim();
      if (!trimmed.contains('=') && !trimmed.contains(';')) {
        sapisid = trimmed;
      } else {
        final cookieMap = <String, String>{};
        for (final part in trimmed.split(';')) {
          final idx = part.indexOf('=');
          if (idx != -1) {
            final k = part.substring(0, idx).trim();
            final v = part.substring(idx + 1).trim();
            if (k.isNotEmpty) {
              cookieMap[k] = v;
            }
          }
        }
        sapisid = cookieMap['__Secure-3PAPISID'] ?? cookieMap['SAPISID'] ?? cookieMap['__Secure-1PAPISID'];
      }

      if (sapisid == null || sapisid.isEmpty) {
        print('[ApiService] SAPISID not found in cookies');
        return null;
      }

      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final input = '$timestamp $sapisid $origin';
      final digest = sha1.convert(utf8.encode(input));
      return 'SAPISIDHASH ${timestamp}_$digest';
    } catch (e) {
      print('[ApiService] Error generating SAPISID hash: $e');
      return null;
    }
  }

  Map<String, dynamic> _buildClientContext() {
    return {
      'client': {
        'clientName': 'WEB_REMIX',
        'clientVersion': '1.20241101.01.00',
        'hl': 'it',
        'gl': 'IT',
      },
      'user': {},
    };
  }

  // --- 1. Quick Picks / Personalized Recommendations ---
  Future<List<Track>> fetchQuickPicks({String? params, int limit = 20}) async {
    // 1. Fetch directly from FEmusic_home (with user cookies if present, yielding authentic personalized Quick Picks!)
    try {
      final uri = Uri.parse('$_innertubeEndpoint/browse?prettyPrint=false');
      final payload = jsonEncode({
        'context': _buildClientContext(),
        'browseId': 'FEmusic_home',
        if (params != null && params.isNotEmpty) 'params': params,
      });

      final res = await _client.post(uri, headers: _buildInnertubeHeaders(), body: payload).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final carouselShelves = _findNodes(data, 'musicCarouselShelfRenderer');
        final standardShelves = _findNodes(data, 'musicShelfRenderer');
        final allShelves = [...carouselShelves, ...standardShelves];

        final tracks = <Track>[];

        // Try exact "Scelte rapide" / "Quick picks" shelf first
        for (final shelf in allShelves) {
          final title = shelf['header']?['musicCarouselShelfBasicHeaderRenderer']?['title']?['runs']?[0]?['text']?.toString() ??
                        shelf['header']?['musicShelfBasicHeaderRenderer']?['title']?['runs']?[0]?['text']?.toString() ?? '';
          final titleLower = title.toLowerCase();
          if (titleLower.contains('scelt') || titleLower.contains('quick')) {
            final contents = shelf['contents'] as List? ?? [];
            for (final item in contents) {
              final track = _parseTrackFromItem(item as Map);
              if (track != null && !tracks.any((t) => t.id == track.id)) {
                tracks.add(track);
              }
            }
            if (tracks.isNotEmpty) break;
          }
        }

        // If no matching titled shelf, try any personalized shelf
        if (tracks.isEmpty) {
          for (final shelf in allShelves) {
            final title = shelf['header']?['musicCarouselShelfBasicHeaderRenderer']?['title']?['runs']?[0]?['text']?.toString() ??
                          shelf['header']?['musicShelfBasicHeaderRenderer']?['title']?['runs']?[0]?['text']?.toString() ?? '';
            final titleLower = title.toLowerCase();
            final isPersonalized = titleLower.contains('ascolta') ||
                                   titleLower.contains('preferit') ||
                                   titleLower.contains('insieme') ||
                                   titleLower.contains('listen') ||
                                   titleLower.contains('again') ||
                                   titleLower.contains('brani') ||
                                   titleLower.contains('consigli');
            if (isPersonalized) {
              final contents = shelf['contents'] as List? ?? [];
              for (final item in contents) {
                final track = _parseTrackFromItem(item as Map);
                if (track != null && !tracks.any((t) => t.id == track.id)) {
                  tracks.add(track);
                }
              }
              if (tracks.length >= 10) break;
            }
          }
        }

        // If still empty, take first shelf with items
        if (tracks.isEmpty && allShelves.isNotEmpty) {
          for (final shelf in allShelves) {
            final contents = shelf['contents'] as List? ?? [];
            for (final item in contents) {
              final track = _parseTrackFromItem(item as Map);
              if (track != null && !tracks.any((t) => t.id == track.id)) {
                tracks.add(track);
              }
            }
            if (tracks.isNotEmpty) break;
          }
        }

        if (tracks.isNotEmpty) {
          return tracks.take(limit).toList();
        }
      }
    } catch (e) {
      print('ApiService fetchQuickPicks error: $e');
    }

    // 2. Fallback: if user is logged in, try FEmusic_history
    final cookie = _storage.getYtmCookie();
    if (cookie != null && cookie.isNotEmpty) {
      try {
        final uri = Uri.parse('$_innertubeEndpoint/browse?prettyPrint=false');
        final payload = jsonEncode({
          'context': _buildClientContext(),
          'browseId': 'FEmusic_history',
        });
        final res = await _client.post(uri, headers: _buildInnertubeHeaders(), body: payload).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final items = [
            ..._findNodes(data, 'musicResponsiveListItemRenderer'),
            ..._findNodes(data, 'musicTwoRowItemRenderer'),
          ];
          final historyTracks = <Track>[];
          for (final item in items) {
            final track = _parseTrackFromItem(item);
            if (track != null && !historyTracks.any((t) => t.id == track.id)) {
              historyTracks.add(track);
            }
          }
          if (historyTracks.isNotEmpty) {
            return historyTracks.take(limit).toList();
          }
        }
      } catch (_) {}
    }

    return _getFallbackPicks();
  }

  // --- 1.1 Home Category / Mood Chips ---
  Future<List<Map<String, String>>> fetchHomeChips() async {
    try {
      final uri = Uri.parse('$_innertubeEndpoint/browse?prettyPrint=false');
      final payload = jsonEncode({
        'context': _buildClientContext(),
        'browseId': 'FEmusic_home',
      });
      final res = await _client.post(uri, headers: _buildInnertubeHeaders(), body: payload).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final chips = <Map<String, String>>[];
        final chipNodes = _findNodes(data, 'chipCloudChipRenderer');
        for (final node in chipNodes) {
          final title = node['text']?['runs']?[0]?['text']?.toString() ?? '';
          final params = node['navigationEndpoint']?['browseEndpoint']?['params']?.toString() ?? '';
          if (title.isNotEmpty) {
            chips.add({'title': title, 'params': params});
          }
        }
        if (chips.isNotEmpty) return chips;
      }
    } catch (_) {}
    return [
      {'title': 'Podcast', 'params': 'ggNCSgQIDBADSgQICRABSgQIBxABSgQICBABSgQIBBABSgQIDhABSgQIAxABSgQIDRABSgQIChABSgQIBhABSgQIBRAB'},
      {'title': 'Energia pura', 'params': 'ggNCSgQIDBABSgQICRADSgQIBxABSgQICBABSgQIBBABSgQIDhABSgQIAxABSgQIDRABSgQIChABSgQIBhABSgQIBRAB'},
      {'title': 'Relax', 'params': 'ggNCSgQIDBABSgQICRABSgQIBxADSgQICBABSgQIBBABSgQIDhABSgQIAxABSgQIDRABSgQIChABSgQIBhABSgQIBRAB'},
      {'title': 'Benessere', 'params': 'ggNCSgQIDBABSgQICRABSgQIBxABSgQICBADSgQIBBABSgQIDhABSgQIAxABSgQIDRABSgQIChABSgQIBhABSgQIBRAB'},
      {'title': 'Attività fisica', 'params': 'ggNCSgQIDBABSgQICRABSgQIBxABSgQICBABSgQIBBADSgQIDhABSgQIAxABSgQIDRABSgQIChABSgQIBhABSgQIBRAB'},
      {'title': 'Festa', 'params': 'ggNCSgQIDBABSgQICRABSgQIBxABSgQICBABSgQIBBABSgQIDhADSgQIAxABSgQIDRABSgQIChABSgQIBhABSgQIBRAB'},
      {'title': 'Tragitto giornaliero', 'params': 'ggNCSgQIDBABSgQICRABSgQIBxABSgQICBABSgQIBBABSgQIDhABSgQIAxADSgQIDRABSgQIChABSgQIBhABSgQIBRAB'},
      {'title': 'Romantico', 'params': 'ggNCSgQIDBABSgQICRABSgQIBxABSgQICBABSgQIBBABSgQIDhABSgQIAxABSgQIDRADSgQIChABSgQIBhABSgQIBRAB'},
      {'title': 'Malinconico', 'params': 'ggNCSgQIDBABSgQICRABSgQIBxABSgQICBABSgQIBBABSgQIDhABSgQIAxABSgQIDRABSgQIChADSgQIBhABSgQIBRAB'},
      {'title': 'Concentrazione', 'params': 'ggNCSgQIDBABSgQICRABSgQIBxABSgQICBABSgQIBBABSgQIDhABSgQIAxABSgQIDRABSgQIChABSgQIBhADSgQIBRAB'},
      {'title': 'Riposo', 'params': 'ggNCSgQIDBABSgQICRABSgQIBxABSgQICBABSgQIBBABSgQIDhABSgQIAxABSgQIDRABSgQIChABSgQIBhABSgQIBRAD'},
    ];
  }

  // --- 2. Home Feed Shelves ---
  Future<Map<String, List<Track>>> fetchHomeSections({String? params}) async {
    final sections = <String, List<Track>>{};

    // 1. If logged in, add "Ascoltati di recente" from FEmusic_history at the top!
    final cookie = _storage.getYtmCookie();
    if (cookie != null && cookie.isNotEmpty) {
      try {
        final uri = Uri.parse('$_innertubeEndpoint/browse?prettyPrint=false');
        final payload = jsonEncode({
          'context': _buildClientContext(),
          'browseId': 'FEmusic_history',
        });
        final res = await _client.post(uri, headers: _buildInnertubeHeaders(), body: payload).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final items = [
            ..._findNodes(data, 'musicResponsiveListItemRenderer'),
            ..._findNodes(data, 'musicTwoRowItemRenderer'),
          ];
          final historyTracks = <Track>[];
          for (final item in items) {
            final track = _parseTrackFromItem(item);
            if (track != null && !historyTracks.any((t) => t.id == track.id)) {
              historyTracks.add(track);
            }
          }
          if (historyTracks.isNotEmpty) {
            sections['Ascoltati di recente'] = historyTracks.take(15).toList();
          }
        }
      } catch (e) {
        print('[ApiService] Error fetching history section: $e');
      }
    }

    // 2. Fetch all dynamic shelves from FEmusic_home
    try {
      final uri = Uri.parse('$_innertubeEndpoint/browse?prettyPrint=false');
      final payload = jsonEncode({
        'context': _buildClientContext(),
        'browseId': 'FEmusic_home',
        if (params != null && params.isNotEmpty) 'params': params,
      });

      final res = await _client.post(uri, headers: _buildInnertubeHeaders(), body: payload).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final carouselShelves = _findNodes(data, 'musicCarouselShelfRenderer');
        final standardShelves = _findNodes(data, 'musicShelfRenderer');
        final allShelves = [...carouselShelves, ...standardShelves];

        for (final shelf in allShelves) {
          final title = shelf['header']?['musicCarouselShelfBasicHeaderRenderer']?['title']?['runs']?[0]?['text']?.toString() ??
                        shelf['header']?['musicShelfBasicHeaderRenderer']?['title']?['runs']?[0]?['text']?.toString() ?? '';
          if (title.isEmpty) continue;

          // Skip "Scelte rapide" as it is rendered separately in the top hero grid
          final titleLower = title.toLowerCase();
          if (titleLower.contains('scelt') || titleLower.contains('quick')) continue;

          final contents = shelf['contents'] as List? ?? [];
          final items = <Track>[];
          for (final item in contents) {
            final track = _parseTrackFromItem(item as Map);
            if (track != null && !items.any((t) => t.id == track.id)) {
              items.add(track);
            }
          }
          if (items.isNotEmpty && !sections.containsKey(title)) {
            sections[title] = items;
          }
        }
      }
    } catch (e) {
      print('ApiService fetchHomeSections error: $e');
    }

    if (sections.isEmpty) {
      sections['Scelte rapide'] = _getFallbackPicks();
    }
    return sections;
  }

  // --- 3. Search ---
  Future<Map<String, dynamic>> search(String query, {String filter = 'all', int limit = 30}) async {
    final tracks = <Track>[];
    final artists = <Artist>[];
    final albums = <Album>[];
    final playlists = <Playlist>[];

    try {
      String? params;
      if (filter == 'tracks' || filter == 'songs') {
        params = 'EgWKAQIIAWoQEAUQCRAKEAMQEBAEEBUQEQ%3D%3D';
      } else if (filter == 'albums') {
        params = 'EgWKAQIYAWoQEAUQCRAKEAMQEBAEEBUQEQ%3D%3D';
      } else if (filter == 'artists') {
        params = 'EgWKAQIgAWoQEAUQCRAKEAMQEBAEEBUQEQ%3D%3D';
      } else if (filter == 'playlists') {
        params = 'EgeKAQQoAEABahAQBRAJEAoQAxAQEAQQFRAR';
      }

      final uri = Uri.parse('$_innertubeEndpoint/search?prettyPrint=false');
      final payload = jsonEncode({
        'context': _buildClientContext(),
        'query': query,
        if (params != null) 'params': params,
      });

      final res = await _client.post(uri, headers: _buildInnertubeHeaders(), body: payload).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;

        // 1. Process card shelf (Top result artist, album, or top tracks)
        final cardShelves = _findNodes(data, 'musicCardShelfRenderer');
        String cardArtistName = '';
        for (final card in cardShelves) {
          final title = card['title']?['runs']?[0]?['text']?.toString() ?? '';
          final browseId = card['title']?['runs']?[0]?['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';
          final thumbs = (card['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
          final thumb = thumbs.isNotEmpty ? (thumbs.last['url']?.toString() ?? '') : '';

          final cardSubtitleRuns = card['subtitle']?['runs'] as List? ?? [];
          final cardSubtitle = cardSubtitleRuns.map((r) => r['text']?.toString() ?? '').join('').toLowerCase();
          final cardIsVideo = cardSubtitle.startsWith('video') || (thumb.contains('i.ytimg.com') && !cardSubtitle.contains('brano'));

          if (!cardIsVideo && title.isNotEmpty && browseId.isNotEmpty) {
            cardArtistName = title;
            if (!artists.any((a) => a.id == browseId)) {
              artists.add(Artist(id: browseId, name: AppConfig.sanitizeArtist(title), picture: AppConfig.formatArtwork(thumb)));
            }
          }

          // Only include card contents if the card is NOT a music video shelf
          if (!cardIsVideo) {
            final cardContents = card['contents'] as List? ?? [];
            for (final c in cardContents) {
              final r = (c as Map)['musicResponsiveListItemRenderer'];
              if (r != null) {
                final flexCols = r['flexColumns'] as List? ?? [];
                final col0 = flexCols.isNotEmpty ? (flexCols[0] as Map)['musicResponsiveListItemFlexColumnRenderer'] : null;
                final songTitle = col0?['text']?['runs']?[0]?['text']?.toString() ?? '';
                final vId = col0?['text']?['runs']?[0]?['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString() ??
                            r['playlistItemData']?['videoId']?.toString() ??
                            r['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId']?.toString() ?? '';
                final cThumbs = (r['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
                                 r['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
                final cThumb = cThumbs.isNotEmpty ? cThumbs.last['url']?.toString() : thumb;

                if (songTitle.isNotEmpty && vId.isNotEmpty && !tracks.any((t) => t.id == vId)) {
                  tracks.add(Track(
                    id: vId,
                    videoId: vId,
                    title: songTitle,
                    artistName: AppConfig.sanitizeArtist(cardArtistName.isNotEmpty ? cardArtistName : 'Artista'),
                    coverUrl: AppConfig.formatArtwork(cThumb),
                    durationMs: 210000,
                  ));
                }
              }
            }
          }
        }

        // 2. Process all responsive items across all sections
        final officialTracks = <Track>[];
        final videoTracks = <Track>[];

        final responsiveNodes = _findNodes(data, 'musicResponsiveListItemRenderer');
        for (final node in responsiveNodes) {
          final flexCols = node['flexColumns'] as List? ?? [];
          if (flexCols.isEmpty) continue;
          final col0 = (flexCols[0] as Map)['musicResponsiveListItemFlexColumnRenderer'];
          final title = col0?['text']?['runs']?[0]?['text']?.toString() ?? '';
          if (title.isEmpty) continue;

          final col1 = flexCols.length > 1 ? (flexCols[1] as Map)['musicResponsiveListItemFlexColumnRenderer'] : null;
          final runs1 = (col1?['text']?['runs'] as List? ?? []);
          final subFull = runs1.map((r) => r['text']).join('');

          final navEp = node['navigationEndpoint'] ?? col0?['text']?['runs']?[0]?['navigationEndpoint'];
          final browseId = navEp?['browseEndpoint']?['browseId']?.toString() ?? '';
          final pageType = navEp?['browseEndpoint']?['browseEndpointContextSupportedConfigs']?['browseEndpointContextMusicConfig']?['pageType']?.toString() ?? '';

          String vId = navEp?['watchEndpoint']?['videoId']?.toString() ??
                       col0?['text']?['runs']?[0]?['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString() ??
                       node['playlistItemData']?['videoId']?.toString() ??
                       node['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId']?.toString() ?? '';

          if (vId.isEmpty) {
            for (final col in flexCols) {
              final runs = (col as Map)['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List? ?? [];
              for (final r in runs) {
                final ep = (r as Map)['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString();
                if (ep != null && ep.isNotEmpty) {
                  vId = ep;
                  break;
                }
              }
              if (vId.isNotEmpty) break;
            }
          }

          final thumbs = (node['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
                          node['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
          final thumb = thumbs.isNotEmpty ? (thumbs.last['url']?.toString() ?? '') : '';

          final subLower = subFull.toLowerCase();
          final isArtist = pageType == 'MUSIC_PAGE_TYPE_ARTIST' || subLower.startsWith('artista') || subLower.startsWith('artist') || filter == 'artists';
          final isAlbum = pageType == 'MUSIC_PAGE_TYPE_ALBUM' || subLower.startsWith('album') || subLower.startsWith('singolo') || subLower.startsWith('ep') || filter == 'albums';
          final isPlaylist = pageType == 'MUSIC_PAGE_TYPE_PLAYLIST' || subLower.startsWith('playlist') || filter == 'playlists';

          // Distinguish official studio tracks from music video uploads
          final isVideo = subLower.startsWith('video') || (thumb.contains('i.ytimg.com') && !subLower.startsWith('brano') && !subLower.startsWith('song'));
          final isOfficialTrack = !isVideo && (subLower.startsWith('brano') || subLower.startsWith('canzone') || subLower.startsWith('song') || filter == 'tracks' || filter == 'songs' || thumb.contains('googleusercontent.com') || thumb.contains('ggpht.com'));
          final isTrack = (isOfficialTrack || isVideo || vId.isNotEmpty) && !isArtist && !isAlbum && !isPlaylist;

          if (isArtist && (browseId.startsWith('UC') || browseId.isNotEmpty)) {
            if (!artists.any((a) => a.name.toLowerCase() == title.toLowerCase())) {
              artists.add(Artist(
                id: browseId.isNotEmpty ? browseId : title,
                name: AppConfig.sanitizeArtist(title),
                picture: AppConfig.formatArtwork(thumb),
              ));
            }
          } else if (isAlbum && (browseId.startsWith('MPREb_') || browseId.startsWith('OLAK5uy_') || browseId.isNotEmpty)) {
            String albArtist = '';
            for (final r in runs1) {
              final t = r['text']?.toString() ?? '';
              if (t != 'Album' && t != 'Singolo' && t != 'EP' && t != ' • ' && !t.contains('202') && !t.contains('201') && !t.contains('199')) {
                albArtist = t;
                break;
              }
            }
            if (!albums.any((al) => al.id == browseId || al.title.toLowerCase() == title.toLowerCase())) {
              albums.add(Album(
                id: browseId,
                title: title,
                artistName: AppConfig.sanitizeArtist(albArtist.isNotEmpty ? albArtist : 'Artista'),
                coverUrl: AppConfig.formatArtwork(thumb),
              ));
            }
          } else if (isPlaylist && (browseId.startsWith('VL') || browseId.startsWith('PL') || browseId.startsWith('RD') || browseId.isNotEmpty)) {
            if (!playlists.any((p) => p.id == browseId || p.title.toLowerCase() == title.toLowerCase())) {
              playlists.add(Playlist(
                id: browseId,
                title: title,
                subtitle: subFull,
                coverUrl: AppConfig.formatArtwork(thumb),
                isLocal: false,
              ));
            }
          } else if (isTrack && vId.isNotEmpty) {
            String trackArtist = '';
            final artistCandidates = <String>[];
            for (final r in runs1) {
              final t = r['text']?.toString() ?? '';
              if (t == 'Brano' || t == 'Video' || t == 'Song' || t == ' • ' || t == ' e ' || t == ' & ' || t.contains(':') || t.contains('visualizzazioni') || t.contains('views') || t.contains('riproduzioni') || t.contains('ascoltatori')) continue;
              if (r['navigationEndpoint'] != null || artistCandidates.isEmpty) {
                artistCandidates.add(t);
              }
            }
            trackArtist = artistCandidates.join(', ');
            if (trackArtist.isEmpty) trackArtist = cardArtistName.isNotEmpty ? cardArtistName : 'Artista';

            final trk = Track(
              id: vId,
              videoId: vId,
              title: title,
              artistName: AppConfig.sanitizeArtist(trackArtist),
              coverUrl: AppConfig.formatArtwork(thumb),
              durationMs: 210000,
            );

            if (isOfficialTrack) {
              if (!officialTracks.any((t) => t.id == vId)) {
                officialTracks.add(trk);
              }
            } else if (isVideo) {
              if (!videoTracks.any((t) => t.id == vId)) {
                videoTracks.add(trk);
              }
            } else {
              if (!officialTracks.any((t) => t.id == vId)) {
                officialTracks.add(trk);
              }
            }
          }
        }

        // 3. Process all two-row items
        final twoRowNodes = _findNodes(data, 'musicTwoRowItemRenderer');
        for (final node in twoRowNodes) {
          final t = _parseTrackFromItem(node);
          if (t != null && !officialTracks.any((x) => x.id == t.id) && !videoTracks.any((x) => x.id == t.id)) {
            if (t.coverUrl.contains('googleusercontent.com') || t.coverUrl.contains('ggpht.com')) {
              officialTracks.add(t);
            } else {
              videoTracks.add(t);
            }
            continue;
          }
          final art = _parseArtistFromItem(node);
          if (art != null && !artists.any((x) => x.id == art.id)) {
            artists.add(art);
            continue;
          }
          final alb = _parseAlbumFromItem(node);
          if (alb != null && !albums.any((x) => x.id == alb.id)) {
            albums.add(alb);
            continue;
          }
          final pl = _parsePlaylistFromItem(node);
          if (pl != null && !playlists.any((x) => x.id == pl.id)) {
            playlists.add(pl);
            continue;
          }
        }

        // 4. Assemble final tracks list: prioritize official audio releases!
        for (final t in officialTracks) {
          if (!tracks.any((x) => x.id == t.id)) {
            tracks.add(t);
          }
        }

        // Deduplicate video tracks against official releases by title
        for (final vt in videoTracks) {
          final normVTitle = vt.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          final hasOfficialMatch = tracks.any((ot) {
            final normOTitle = ot.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
            return normOTitle == normVTitle || (normVTitle.contains(normOTitle) && normOTitle.length >= 4);
          });
          if (!hasOfficialMatch && !tracks.any((x) => x.id == vt.id)) {
            tracks.add(vt);
          }
        }
      }
    } catch (e) {
      print('ApiService search error: $e');
    }

    return {
      'tracks': tracks.take(limit).toList(),
      'artists': artists.take(limit).toList(),
      'albums': albums.take(limit).toList(),
      'playlists': playlists.take(limit).toList(),
    };
  }

  // --- 3b. Resolve Official High-Resolution Track Artwork ---
  Future<Map<String, String>?> resolveOfficialArtwork(Track track) async {
    try {
      // 1. Clean title and artist
      String cleanTitle = track.title
          .replaceAll(RegExp(r'\s*\(official\s*(?:video|audio|music\s*video|hd|4k|visualizer)?\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\[official\s*(?:video|audio|music\s*video|hd|4k|visualizer)?\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\(visualizer\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\[visualizer\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\(audio\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\[audio\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\(video\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\(con\s+[^)]+\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\(feat\.\s+[^)]+\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\(ft\.\s+[^)]+\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*-\s*official.*$', caseSensitive: false), '')
          .trim();

      String cleanArtist = track.artistName;
      if (cleanArtist.toLowerCase() == 'artista' ||
          cleanArtist.toLowerCase() == 'unknown artist' ||
          cleanArtist.toLowerCase() == 'artista sconosciuto') {
        cleanArtist = '';
      } else {
        if (cleanArtist.contains(',')) {
          cleanArtist = cleanArtist.split(',')[0].trim();
        }
        if (cleanArtist.contains('&')) {
          cleanArtist = cleanArtist.split('&')[0].trim();
        }
        if (cleanArtist.contains(' e ')) {
          cleanArtist = cleanArtist.split(' e ')[0].trim();
        }
      }

      final query = cleanArtist.isNotEmpty ? '$cleanArtist $cleanTitle' : cleanTitle;

      // Primary: iTunes Search API (instant, official 600x600 square studio artwork)
      try {
        final itunesUri = Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=song&limit=3');
        final itunesRes = await _client.get(itunesUri).timeout(const Duration(seconds: 4));
        if (itunesRes.statusCode == 200) {
          final itunesData = jsonDecode(itunesRes.body) as Map<String, dynamic>;
          final results = itunesData['results'] as List? ?? [];
          if (results.isNotEmpty) {
            final item = results[0] as Map;
            final rawArt = item['artworkUrl100']?.toString() ?? '';
            if (rawArt.isNotEmpty) {
              final highRes = rawArt.replaceAll('100x100bb', '600x600bb');
              return {
                'coverUrl': highRes,
                'album': item['collectionName']?.toString() ?? '',
                'artist': item['artistName']?.toString() ?? cleanArtist,
              };
            }
          }
        }
      } catch (_) {}

      // Secondary: YouTube Music tracks search (filter: 'tracks')
      try {
        final ytmRes = await search(query, filter: 'tracks', limit: 3);
        final ytmTracks = (ytmRes['tracks'] as List<Track>?) ?? [];
        for (final t in ytmTracks) {
          if (t.coverUrl.contains('googleusercontent.com') || t.coverUrl.contains('ggpht.com')) {
            return {
              'coverUrl': t.coverUrl,
              'album': t.albumName,
              'artist': t.artistName,
            };
          }
        }
      } catch (_) {}
    } catch (_) {}
    return null;
  }

  // --- 4. Resolve Audio Stream with Multi-Source Fallback ---
  Future<String> resolveAudioStream(Track track) async {
    final vId = track.videoId.isNotEmpty ? track.videoId : track.id;

    // 1. Primary: YoutubeExplode (itag 18 has ratebypass=yes, completely bypassing BotGuard/SABR 1MB cutoff)
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(vId).timeout(const Duration(seconds: 10));
      
      // Check itag 18 (MP4 with AAC stereo audio and ratebypass=yes)
      final itag18 = manifest.muxed.where((s) => s.tag == 18).firstOrNull;
      if (itag18 != null && itag18.url.toString().isNotEmpty) {
        print('[ApiService] Resolved stream for $vId: itag=18 (ratebypass=yes, size=${itag18.size.totalBytes})');
        return itag18.url.toString();
      }

      final audios = manifest.audioOnly.toList();
      if (audios.isNotEmpty) {
        final preferred = audios.firstWhere(
          (s) => s.tag == 140,
          orElse: () => audios.firstWhere(
            (s) => s.tag == 251,
            orElse: () => audios.withHighestBitrate(),
          ),
        );
        final url = preferred.url.toString();
        if (url.isNotEmpty) {
          print('[ApiService] Resolved stream for $vId: itag=${preferred.tag} container=${preferred.container.name} bitrate=${preferred.bitrate}');
          return url;
        }
      }
    } catch (e) {
      print('YoutubeExplode stream resolution failed for $vId: $e, trying Invidious/Piped fallbacks');
    }

    // 2. Secondary: Invidious Instances
    final invidiousEndpoints = [
      'https://inv.tux.pizza',
      'https://invidious.nerdvpn.de',
      'https://yewtu.be',
      'https://invidious.private.coffee',
      'https://inv.nadeko.net',
    ];

    for (final endpoint in invidiousEndpoints) {
      try {
        final uri = Uri.parse('$endpoint/api/v1/videos/$vId?fields=adaptiveFormats');
        final res = await _client.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final formats = data['adaptiveFormats'] as List? ?? [];
          final audioFormats = formats.where((f) => (f['type']?.toString() ?? '').contains('audio')).toList();
          if (audioFormats.isNotEmpty) {
            final streamUrl = audioFormats.first['url']?.toString() ?? '';
            if (streamUrl.isNotEmpty) return streamUrl;
          }
        }
      } catch (_) {}
    }

    // 3. Tertiary: Piped API Instances
    final pipedEndpoints = [
      'https://pipedapi.kavin.rocks',
      'https://pipedapi.drgns.space',
      'https://api.piped.privacydev.net',
      'https://piped-api.lunar.icu',
    ];

    for (final endpoint in pipedEndpoints) {
      try {
        final uri = Uri.parse('$endpoint/streams/$vId');
        final res = await _client.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final audioStreams = data['audioStreams'] as List? ?? [];
          if (audioStreams.isNotEmpty) {
            final streamUrl = audioStreams.first['url']?.toString() ?? '';
            if (streamUrl.isNotEmpty) return streamUrl;
          }
        }
      } catch (_) {}
    }

    // 4. Fallback Proxy if configured
    if (baseUrl.isNotEmpty) {
      return '$baseUrl/api/stream.mp4?id=${Uri.encodeComponent(vId)}';
    }

    throw Exception('Unable to resolve audio stream for track $vId');
  }

  // --- 5. Lyrics via LRCLib ---
  Future<Lyrics?> fetchLyrics(Track track) async {
    try {
      String title = track.title;
      String artist = track.artistName;
      if (artist.toLowerCase() == 'artista' || artist.toLowerCase() == 'unknown artist') {
        artist = '';
      }

      // Clean YouTube/video suffixes
      String cleanTitle = title
          .replaceAll(RegExp(r'\s*\(official\s*(?:video|audio|music\s*video|hd|4k)?\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\[official\s*(?:video|audio|music\s*video|hd|4k)?\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\(visualizer\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\[visualizer\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\(audio\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\[audio\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\(video\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*\[video\]', caseSensitive: false), '')
          .trim();

      if (artist.isNotEmpty) {
        final durSec = track.durationMs ~/ 1000;
        final uri = Uri.parse(
          'https://lrclib.net/api/get?track_name=${Uri.encodeComponent(cleanTitle)}&artist_name=${Uri.encodeComponent(artist)}&duration=$durSec',
        );
        final res = await _client.get(uri, headers: {
          'User-Agent': 'Preluded/2.0.0 (https://github.com/mrbana69/web-music)',
        }).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final synced = data['syncedLyrics']?.toString() ?? '';
          final plain = data['plainLyrics']?.toString() ?? '';
          if (synced.isNotEmpty) {
            return Lyrics.parse(rawLrc: synced);
          } else if (plain.isNotEmpty) {
            return Lyrics(plainText: plain, isSynced: false);
          }
        }
      }

      // Search fallback on LRCLib
      final q = artist.isNotEmpty ? '$cleanTitle $artist' : cleanTitle;
      final searchUri = Uri.parse('https://lrclib.net/api/search?q=${Uri.encodeComponent(q)}');
      final sRes = await _client.get(searchUri, headers: {'User-Agent': 'Preluded/2.0.0'}).timeout(const Duration(seconds: 4));
      if (sRes.statusCode == 200) {
        final list = jsonDecode(sRes.body) as List? ?? [];
        if (list.isNotEmpty) {
          final first = list[0] as Map;
          final synced = first['syncedLyrics']?.toString() ?? '';
          final plain = first['plainLyrics']?.toString() ?? '';
          if (synced.isNotEmpty) {
            return Lyrics.parse(rawLrc: synced);
          } else if (plain.isNotEmpty) {
            return Lyrics(plainText: plain, isSynced: false);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // --- 6. Track Radio Mix (InnerTube /next with RDAMVM) ---
  Future<List<Track>> fetchMix(Track track) async {
    final vId = track.videoId.isNotEmpty ? track.videoId : track.id;
    try {
      final uri = Uri.parse('$_innertubeEndpoint/next?prettyPrint=false');
      final payload = jsonEncode({
        'context': _buildClientContext(),
        'videoId': vId,
        'playlistId': 'RDAMVM$vId',
      });

      final res = await _client.post(uri, headers: _buildInnertubeHeaders(), body: payload).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final panelNodes = _findNodes(data, 'playlistPanelVideoRenderer');

        final tracks = <Track>[];
        final seenIds = <String>{vId};

        for (final renderer in panelNodes) {
          final tId = renderer['videoId']?.toString() ?? '';
          if (tId.isEmpty || seenIds.contains(tId)) continue;
          seenIds.add(tId);

          final title = renderer['title']?['runs']?[0]?['text']?.toString() ?? '';
          final shortArtist = ((renderer['shortBylineText']?['runs'] as List?) ?? []).map((r) => r['text']).join('');

          String artistId = '';
          String albumName = '';
          String albumId = '';
          final longRuns = (renderer['longBylineText']?['runs'] as List?) ?? [];
          for (final run in longRuns) {
            final endpoint = run['navigationEndpoint']?['browseEndpoint'];
            final pageType = endpoint?['browseEndpointContextSupportedConfigs']?['browseEndpointContextMusicConfig']?['pageType']?.toString() ?? '';
            if (pageType == 'MUSIC_PAGE_TYPE_ARTIST') {
              artistId = endpoint?['browseId']?.toString() ?? '';
            } else if (pageType == 'MUSIC_PAGE_TYPE_ALBUM') {
              albumId = endpoint?['browseId']?.toString() ?? '';
              albumName = run['text']?.toString() ?? '';
            }
          }

          final thumb = _extractLargestThumbnail(renderer['thumbnail']);

          int durationMs = 210000;
          final durText = renderer['lengthText']?['runs']?[0]?['text']?.toString();
          if (durText != null) {
            final parts = durText.split(':').map((s) => int.tryParse(s) ?? 0).toList();
            if (parts.length == 2) {
              durationMs = (parts[0] * 60 + parts[1]) * 1000;
            } else if (parts.length == 3) {
              durationMs = (parts[0] * 3600 + parts[1] * 60 + parts[2]) * 1000;
            }
          }

          if (title.isNotEmpty) {
            tracks.add(Track(
              id: tId,
              videoId: tId,
              title: title,
              artistName: AppConfig.sanitizeArtist(shortArtist.isNotEmpty ? shortArtist : track.artistName),
              artistId: artistId,
              albumName: albumName,
              albumId: albumId,
              coverUrl: AppConfig.formatArtwork(thumb.isNotEmpty ? thumb : track.coverUrl),
              durationMs: durationMs,
            ));
          }
        }
        if (tracks.isNotEmpty) return tracks;
      }
    } catch (e) {
      print('ApiService fetchMix error: $e');
    }

    // Fallback: search tracks by artist
    try {
      final fallbackQuery = '${track.artistName} mix';
      final searchRes = await search(fallbackQuery, filter: 'tracks', limit: 25);
      final tracks = searchRes['tracks'] as List<Track>? ?? [];
      final filtered = tracks.where((t) => t.id != vId && t.videoId != vId).toList();
      if (filtered.isNotEmpty) return filtered;
    } catch (_) {}

    return [];
  }

  // --- 7. Artist Details ---
  Future<Artist?> fetchArtist(String artistId) async {
    try {
      var targetId = artistId.trim();

      // If artistId is not a channel ID (e.g. name or empty), perform fallback search!
      if (!targetId.startsWith('UC')) {
        if (targetId.isNotEmpty) {
          final searchRes = await search(targetId, filter: 'artists');
          final found = (searchRes['artists'] as List<Artist>).firstOrNull;
          if (found != null && found.id.startsWith('UC')) {
            targetId = found.id;
          }
        }
        if (!targetId.startsWith('UC')) {
          return null;
        }
      }

      final uri = Uri.parse('$_innertubeEndpoint/browse?prettyPrint=false');
      final payload = jsonEncode({
        'context': _buildClientContext(),
        'browseId': targetId,
      });

      final res = await _client.post(uri, headers: _buildInnertubeHeaders(), body: payload).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final header = data['header']?['musicImmersiveHeaderRenderer'] ??
                       data['header']?['musicVisualHeaderRenderer'] ??
                       data['header']?['musicResponsiveHeaderRenderer'] ??
                       data['header']?['musicHeaderRenderer'];
        final name = header?['title']?['runs']?[0]?['text']?.toString() ?? 'Artista';
        
        // Robust thumbnail search
        String thumb = '';
        final thumbs = (header?['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
                        header?['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
        if (thumbs.isNotEmpty) {
          thumb = thumbs.last['url']?.toString() ?? '';
        } else {
          thumb = _extractLargestThumbnail(header ?? data);
        }

        final desc = header?['description']?['runs']?[0]?['text']?.toString() ?? '';

        // Extract top tracks
        final rawTracks = _findNodes(data, 'musicResponsiveListItemRenderer');
        final topTracks = <Track>[];
        for (final item in rawTracks) {
          final t = _parseTrackFromItem(item);
          if (t != null) {
            topTracks.add(t.copyWith(
              artistName: (t.artistName == 'Artista' || t.artistName.isEmpty) ? name : t.artistName,
              artistId: t.artistId.isEmpty ? targetId : t.artistId,
            ));
          }
        }

        // Extract carousels for Album, Singles & EPs, Playlists, etc.
        final carousels = _findNodes(data, 'musicCarouselShelfRenderer');

        final albums = <Album>[];
        final singles = <Album>[];
        final playlists = <Playlist>[];

        for (final c in carousels) {
          final cTitle = (c['header']?['musicCarouselShelfBasicHeaderRenderer']?['title']?['runs']?[0]?['text'] ?? '').toString().toLowerCase();
          final items = _findNodes(c, 'musicTwoRowItemRenderer');

          for (final item in items) {
            final subRuns = item['subtitle']?['runs'] as List? ?? [];
            final subText = subRuns.map((r) => r['text']?.toString() ?? '').join('');
            final subLower = subText.toLowerCase();
            final bId = item['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ??
                        item['title']?['runs']?[0]?['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';

            if (bId.startsWith('UC')) {
              // Related artist, ignore here
              continue;
            }

            if (bId.startsWith('VL') || bId.startsWith('PL') || subLower.contains('playlist') || cTitle.contains('playlist') || cTitle.contains('primo piano') || cTitle.contains('featured') || cTitle.contains('appare in')) {
              final pl = _parsePlaylistFromItem(item);
              if (pl != null && !playlists.any((p) => p.id == pl.id)) {
                playlists.add(pl);
              }
            } else if (cTitle.contains('singol') || cTitle.contains('single') || cTitle.contains('ep') || subLower.contains('singol') || subLower.contains('single') || subLower.contains('ep')) {
              final isEp = cTitle.contains('ep') || subLower.contains('ep');
              final al = _parseAlbumFromTwoRow(item, name, targetId, isEp ? 'EP' : 'Single');
              if (al != null && !singles.any((s) => s.id == al.id)) {
                singles.add(al);
              }
            } else if (cTitle.contains('album') || subLower.contains('album') || bId.startsWith('MPREb_') || bId.startsWith('OLAK5uy_')) {
              final al = _parseAlbumFromTwoRow(item, name, targetId, 'Album');
              if (al != null && !albums.any((a) => a.id == al.id)) {
                albums.add(al);
              }
            }
          }
        }

        // Fallback: If no carousels were categorized, parse generic musicTwoRowItemRenderer
        if (albums.isEmpty && singles.isEmpty && playlists.isEmpty) {
          final rawAlbums = _findNodes(data, 'musicTwoRowItemRenderer');
          for (final item in rawAlbums) {
            final subRuns = item['subtitle']?['runs'] as List? ?? [];
            final subText = subRuns.map((r) => r['text']?.toString() ?? '').join('').toLowerCase();
            final bId = item['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';
            if (bId.startsWith('UC')) continue;

            if (bId.startsWith('VL') || bId.startsWith('PL') || subText.contains('playlist')) {
              final pl = _parsePlaylistFromItem(item);
              if (pl != null && !playlists.any((p) => p.id == pl.id)) {
                playlists.add(pl);
              }
            } else if (subText.contains('singol') || subText.contains('single') || subText.contains('ep')) {
              final al = _parseAlbumFromTwoRow(item, name, targetId, subText.contains('ep') ? 'EP' : 'Single');
              if (al != null && !singles.any((s) => s.id == al.id)) {
                singles.add(al);
              }
            } else {
              final al = _parseAlbumFromTwoRow(item, name, targetId, 'Album');
              if (al != null && !albums.any((a) => a.id == al.id)) {
                albums.add(al);
              }
            }
          }
        }

        return Artist(
          id: targetId,
          name: AppConfig.sanitizeArtist(name),
          picture: AppConfig.formatArtwork(thumb),
          bio: desc,
          topTracks: topTracks,
          albums: albums,
          singles: singles,
          playlists: playlists,
        );
      }
    } catch (e) {
      print('ApiService fetchArtist error: $e');
    }
    return null;
  }

  // --- 8. Album Details ---
  Future<Album?> fetchAlbum(String albumId) async {
    try {
      var targetId = albumId.trim();

      // If targetId is an OLAK5uy_ playlist ID, prefix with 'VL' for YouTube Music InnerTube
      if (targetId.startsWith('OLAK5uy_')) {
        targetId = 'VL$targetId';
      }

      // If targetId is not a valid album browse ID (e.g. title or empty), perform fallback search!
      if (!targetId.startsWith('MPREb_') && !targetId.startsWith('VL')) {
        if (targetId.isNotEmpty) {
          final searchRes = await search(targetId, filter: 'albums');
          final found = (searchRes['albums'] as List<Album>).firstOrNull;
          if (found != null && (found.id.startsWith('MPREb_') || found.id.startsWith('OLAK5uy_') || found.id.startsWith('VL'))) {
            targetId = found.id.startsWith('OLAK5uy_') ? 'VL${found.id}' : found.id;
          }
        }
        if (!targetId.startsWith('MPREb_') && !targetId.startsWith('VL')) {
          return null;
        }
      }

      final uri = Uri.parse('$_innertubeEndpoint/browse?prettyPrint=false');
      final payload = jsonEncode({
        'context': _buildClientContext(),
        'browseId': targetId,
      });

      final res = await _client.post(uri, headers: _buildInnertubeHeaders(), body: payload).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        
        final respHeader = _findNodes(data, 'musicResponsiveHeaderRenderer').firstOrNull;
        final detailHeader = _findNodes(data, 'musicDetailHeaderRenderer').firstOrNull;
        final header = respHeader ?? detailHeader ?? data['header']?['musicDetailHeaderRenderer'] ?? data['header']?['musicResponsiveHeaderRenderer'] ?? data['header']?['musicEditablePlaylistDetailHeaderRenderer']?['header']?['musicResponsiveHeaderRenderer'];

        final title = header?['title']?['runs']?[0]?['text']?.toString() ?? 'Album';
        
        // Extract artist and artistId
        String artist = '';
        String artistId = '';
        final straplineRuns = header?['straplineTextOne']?['runs'] as List? ?? [];
        for (final r in straplineRuns) {
          final t = (r as Map)['text']?.toString() ?? '';
          final bId = r['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';
          if (t.isNotEmpty && artist.isEmpty) artist = t;
          if (bId.isNotEmpty && artistId.isEmpty && bId.startsWith('UC')) artistId = bId;
        }

        final subRuns = header?['subtitle']?['runs'] as List? ?? [];
        for (final r in subRuns) {
          final t = (r as Map)['text']?.toString() ?? '';
          final bId = r['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';
          if (bId.startsWith('UC')) {
            if (artist.isEmpty || artist == 'Artista') artist = t;
            if (artistId.isEmpty) artistId = bId;
            break;
          }
        }

        // Secondary fallback for artist in subtitle (non-metadata text)
        if (artist.isEmpty || artist == 'Artista') {
          for (final r in subRuns) {
            final t = (r as Map)['text']?.toString() ?? '';
            if (t != 'Album' && t != 'Singolo' && t != 'EP' && t != ' • ' && !t.contains('19') && !t.contains('20') && !t.contains('brano') && !t.contains('brani')) {
              artist = t;
              break;
            }
          }
        }
        if (artist.isEmpty) artist = 'Artista';

        // Extract year & release type
        String year = '';
        String type = 'Album';
        for (final r in subRuns) {
          final txt = (r as Map)['text']?.toString() ?? '';
          final lower = txt.toLowerCase();
          if (lower.contains('singol') || lower.contains('single')) {
            type = 'Single';
          } else if (lower.contains('ep')) {
            type = 'EP';
          } else if (lower.contains('album')) {
            type = 'Album';
          }
          final yearMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(txt);
          if (yearMatch != null) {
            year = yearMatch.group(1) ?? '';
          }
        }

        // Robust cover artwork extraction
        String cover = '';
        final thumbs = (header?['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
                        header?['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
        if (thumbs.isNotEmpty) {
          cover = thumbs.last['url']?.toString() ?? '';
        } else {
          cover = _extractLargestThumbnail(header ?? data);
        }

        final formattedAlbumCover = AppConfig.formatArtwork(cover);

        // Extract tracks
        final rawTracks = _findNodes(data, 'musicResponsiveListItemRenderer');
        final tracks = <Track>[];
        for (final item in rawTracks) {
          final t = _parseTrackFromItem(item);
          if (t != null) {
            final hasTrackCover = t.coverUrl.isNotEmpty && !t.coverUrl.contains('resources.tidal.com/images/default');
            final hasAlbumCover = formattedAlbumCover.isNotEmpty && !formattedAlbumCover.contains('resources.tidal.com/images/default');
            final effectiveCover = hasTrackCover
                ? t.coverUrl
                : (hasAlbumCover
                    ? formattedAlbumCover
                    : (t.videoId.isNotEmpty ? 'https://i.ytimg.com/vi/${t.videoId}/hqdefault.jpg' : formattedAlbumCover));

            tracks.add(t.copyWith(
              albumName: title,
              albumId: targetId,
              artistName: (t.artistName.isNotEmpty && t.artistName != 'Artista' && t.artistName != 'Unknown Artist')
                  ? t.artistName
                  : (artist != 'Artista' ? artist : t.artistName),
              artistId: t.artistId.isNotEmpty ? t.artistId : artistId,
              coverUrl: effectiveCover,
            ));
          }
        }

        return Album(
          id: targetId,
          title: title,
          artistName: AppConfig.sanitizeArtist(artist),
          artistId: artistId,
          coverUrl: AppConfig.formatArtwork(cover),
          year: year,
          type: type,
          tracks: tracks,
        );
      }
    } catch (e) {
      print('ApiService fetchAlbum error: $e');
    }
    return null;
  }

  // --- 9. Playlist Details ---
  Future<Playlist?> fetchPlaylist(String playlistId) async {
    try {
      final browseId = playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
      final uri = Uri.parse('$_innertubeEndpoint/browse?prettyPrint=false');
      final payload = jsonEncode({
        'context': _buildClientContext(),
        'browseId': browseId,
      });

      final res = await _client.post(uri, headers: _buildInnertubeHeaders(), body: payload).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final header = data['header']?['musicDetailHeaderRenderer'] ??
                       data['header']?['musicResponsiveHeaderRenderer'] ??
                       data['header']?['musicEditablePlaylistDetailHeaderRenderer']?['header']?['musicResponsiveHeaderRenderer'];
        final title = header?['title']?['runs']?[0]?['text']?.toString() ?? 'Playlist';
        final subtitle = header?['straplineTextOne']?['runs']?[0]?['text']?.toString() ??
                         header?['subtitle']?['runs']?[0]?['text']?.toString() ?? '';
        final thumbs = (header?['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
                        header?['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
        final cover = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : '';

        final rawTracks = _findNodes(data, 'musicResponsiveListItemRenderer');
        final tracks = <Track>[];
        for (final item in rawTracks) {
          final t = _parseTrackFromItem(item);
          if (t != null) {
            tracks.add(t);
          }
        }

        return Playlist(
          id: playlistId,
          title: title,
          subtitle: subtitle.isNotEmpty ? subtitle : '${tracks.length} brani',
          coverUrl: AppConfig.formatArtwork((cover != null && cover.isNotEmpty) ? cover : (tracks.isNotEmpty ? tracks.first.coverUrl : '')),
          tracks: tracks,
          isLocal: false,
        );
      }
    } catch (e) {
      print('ApiService fetchPlaylist error: $e');
    }
    return null;
  }

  Album? _parseAlbumFromTwoRow(Map item, String defaultArtist, [String defaultArtistId = '', String explicitType = '']) {
    try {
      final renderer = item['musicTwoRowItemRenderer'] ?? item;
      final nav = renderer['navigationEndpoint'] ?? renderer['title']?['runs']?[0]?['navigationEndpoint'];
      final bId = nav?['browseEndpoint']?['browseId']?.toString();
      if (bId == null || bId.isEmpty) return null;

      // Filter: only allow genuine album or single browse IDs (reject related artists UC... and playlists)
      final pageType = nav?['browseEndpoint']?['browseEndpointContextSupportedConfigs']?['browseEndpointContextMusicConfig']?['pageType']?.toString() ?? '';
      final isAlbumId = bId.startsWith('MPREb_') || bId.startsWith('OLAK5uy_') || pageType == 'MUSIC_PAGE_TYPE_ALBUM';
      if (!isAlbumId && (bId.startsWith('UC') || bId.startsWith('VLPL') || bId.startsWith('PL'))) return null;

      final title = renderer['title']?['runs']?[0]?['text']?.toString() ?? 'Album';
      
      // Robust thumbnail extraction
      String thumb = '';
      final thumbs = (renderer['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
                      renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
      if (thumbs.isNotEmpty) {
        thumb = thumbs.last['url']?.toString() ?? '';
      } else {
        thumb = _extractLargestThumbnail(renderer);
      }

      final subRuns = renderer['subtitle']?['runs'] as List? ?? [];
      String year = '';
      String detectedType = explicitType;
      for (final r in subRuns) {
        final txt = (r as Map)['text']?.toString() ?? '';
        final lower = txt.toLowerCase();
        if (detectedType.isEmpty) {
          if (lower.contains('singol') || lower.contains('single')) {
            detectedType = 'Single';
          } else if (lower.contains('ep')) {
            detectedType = 'EP';
          } else if (lower.contains('album')) {
            detectedType = 'Album';
          }
        }
        final m = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(txt);
        if (m != null) {
          year = m.group(1) ?? '';
        }
      }
      if (detectedType.isEmpty) {
        detectedType = 'Album';
      }

      return Album(
        id: bId,
        title: title,
        artistName: defaultArtist,
        artistId: defaultArtistId,
        coverUrl: AppConfig.formatArtwork(thumb),
        year: year,
        type: detectedType,
      );
    } catch (_) {
      return null;
    }
  }

  // --- 9. Innertube & Google Library Sync ---
  Future<GoogleUser?> fetchYtmAccountInfo(String cookieString) async {
    try {
      final uri = Uri.parse('$_innertubeEndpoint/account/account_menu?prettyPrint=false');
      final payload = jsonEncode({
        'context': _buildClientContext(),
      });

      final headers = _buildInnertubeHeaders(cookieString);

      final res = await _client.post(uri, headers: headers, body: payload).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final headerNodes = _findNodes(data, 'activeAccountHeaderRenderer');
        if (headerNodes.isNotEmpty) {
          final header = headerNodes.first;
          final name = header['accountName']?['runs']?[0]?['text']?.toString() ??
                       header['accountName']?['simpleText']?.toString() ?? 'Utente Google';
          final email = header['email']?['runs']?[0]?['text']?.toString() ??
                        header['email']?['simpleText']?.toString() ?? '';
          final thumbs = header['accountPhoto']?['thumbnails'] as List? ?? [];
          final avatar = thumbs.isNotEmpty ? thumbs.last['url']?.toString() ?? '' : '';

          return GoogleUser(
            name: name,
            email: email,
            avatarUrl: AppConfig.formatArtwork(avatar),
            cookie: cookieString,
          );
        }
      }
    } catch (e) {
      print('ApiService fetchYtmAccountInfo error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> syncGoogleLibrary({String? token, String? cookie}) async {
    final likedSongs = <Track>[];
    final playlists = <Playlist>[];
    GoogleUser? user;

    final cookieToUse = cookie ?? _storage.getYtmCookie();

    // 1. Sync via Innertube if cookie is available
    if (cookieToUse != null && cookieToUse.isNotEmpty) {
      print('[ApiService] Starting Google Library sync via Innertube with cookies (len=${cookieToUse.length})...');
      user = await fetchYtmAccountInfo(cookieToUse);
      final innertubeHeaders = _buildInnertubeHeaders(cookieToUse);

      // 1.1 Liked Songs via Innertube (Try VLLM, FEmusic_liked_videos, VLSE)
      for (final likedBrowseId in ['VLLM', 'FEmusic_liked_videos', 'VLSE']) {
        try {
          final uri = Uri.parse('$_innertubeEndpoint/browse?prettyPrint=false');
          final payload = jsonEncode({
            'context': _buildClientContext(),
            'browseId': likedBrowseId,
          });
          final res = await _client.post(uri, headers: innertubeHeaders, body: payload).timeout(const Duration(seconds: 10));
          print('[syncGoogleLibrary] $likedBrowseId HTTP ${res.statusCode}, len=${res.body.length}');
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            final items = [
              ..._findNodes(data, 'musicResponsiveListItemRenderer'),
              ..._findNodes(data, 'playlistPanelVideoRenderer'),
              ..._findNodes(data, 'musicTwoRowItemRenderer'),
            ];
            for (final item in items) {
              final track = _parseTrackFromItem(item);
              if (track != null && !likedSongs.any((t) => t.id == track.id)) {
                likedSongs.add(track.copyWith(isLiked: true));
              }
            }
            print('[syncGoogleLibrary] $likedBrowseId parsed ${likedSongs.length} liked tracks (from ${items.length} raw nodes)');
            if (likedSongs.isNotEmpty) {
              break;
            }
          } else {
            print('[syncGoogleLibrary] $likedBrowseId returned non-200: ${res.body.substring(0, (res.body.length).clamp(0, 200))}');
          }
        } catch (e) {
          print('Error fetching liked songs for $likedBrowseId: $e');
        }
      }

      // 1.2 Playlists via Innertube (Try FEmusic_library_playlists, FEmusic_liked_playlists, FEmusic_library_landing)
      for (final plBrowseId in ['FEmusic_library_playlists', 'FEmusic_liked_playlists', 'FEmusic_library_landing']) {
        try {
          final uri = Uri.parse('$_innertubeEndpoint/browse?prettyPrint=false');
          final payload = jsonEncode({
            'context': _buildClientContext(),
            'browseId': plBrowseId,
          });
          final res = await _client.post(uri, headers: innertubeHeaders, body: payload).timeout(const Duration(seconds: 10));
          print('[syncGoogleLibrary] $plBrowseId HTTP ${res.statusCode}, len=${res.body.length}');
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            final items = [
              ..._findNodes(data, 'musicTwoRowItemRenderer'),
              ..._findNodes(data, 'musicResponsiveListItemRenderer'),
            ];
            for (final item in items) {
              final pl = _parsePlaylistFromItem(item);
              if (pl != null && !playlists.any((p) => p.id == pl.id)) {
                playlists.add(pl);
              }
            }
            print('[syncGoogleLibrary] $plBrowseId parsed ${playlists.length} playlists (from ${items.length} raw nodes)');
          } else {
            print('[syncGoogleLibrary] $plBrowseId returned non-200: ${res.body.substring(0, (res.body.length).clamp(0, 200))}');
          }
        } catch (e) {
          print('Error fetching playlists for $plBrowseId: $e');
        }
      }
      print('[syncGoogleLibrary] Innertube sync found: ${likedSongs.length} liked tracks, ${playlists.length} playlists');
    }

    // 2. Fallback / Additional Sync via OAuth token if provided
    if (token != null && token.isNotEmpty) {
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

      if (user == null) {
        try {
          final userRes = await _client.get(Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'), headers: headers).timeout(const Duration(seconds: 6));
          if (userRes.statusCode == 200) {
            final uData = jsonDecode(userRes.body);
            user = GoogleUser(
              name: uData['name']?.toString() ?? 'Utente Google',
              email: uData['email']?.toString() ?? '',
              avatarUrl: uData['picture']?.toString() ?? '',
              token: token,
              cookie: cookieToUse,
            );
          }
        } catch (_) {}
      }

      if (likedSongs.isEmpty) {
        for (final plId in ['LM', 'LL']) {
          try {
            final lmRes = await _client.get(
              Uri.parse('https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails&playlistId=$plId&maxResults=50'),
              headers: headers,
            ).timeout(const Duration(seconds: 8));

            if (lmRes.statusCode == 200) {
              final data = jsonDecode(lmRes.body);
              final items = data['items'] as List? ?? [];
              for (final item in items) {
                final snippet = item['snippet'];
                final title = snippet?['title']?.toString() ?? '';
                final channel = snippet?['videoOwnerChannelTitle']?.toString() ?? snippet?['channelTitle']?.toString() ?? 'Artist';
                final vId = item['contentDetails']?['videoId']?.toString() ?? snippet?['resourceId']?.videoId?.toString() ?? '';
                final thumbs = snippet?['thumbnails'];
                final rawThumb = thumbs?['high']?['url']?.toString() ?? thumbs?['medium']?['url']?.toString() ?? '';

                if (vId.isNotEmpty && title.isNotEmpty && title != 'Deleted video' && title != 'Private video') {
                  likedSongs.add(Track(
                    id: vId,
                    videoId: vId,
                    title: title,
                    artistName: AppConfig.sanitizeArtist(channel),
                    coverUrl: AppConfig.formatArtwork(rawThumb),
                    durationMs: 210000,
                    isLiked: true,
                  ));
                }
              }
              if (likedSongs.isNotEmpty) break;
            }
          } catch (_) {}
        }
      }

      if (playlists.isEmpty) {
        try {
          final plRes = await _client.get(
            Uri.parse('https://www.googleapis.com/youtube/v3/playlists?part=snippet,contentDetails&mine=true&maxResults=50'),
            headers: headers,
          ).timeout(const Duration(seconds: 8));

          if (plRes.statusCode == 200) {
            final data = jsonDecode(plRes.body);
            final items = data['items'] as List? ?? [];
            for (final p in items) {
              final snippet = p['snippet'];
              final plId = p['id']?.toString() ?? '';
              final title = snippet?['title']?.toString() ?? 'Playlist';
              final thumbs = snippet?['thumbnails'];
              final rawThumb = thumbs?['high']?['url']?.toString() ?? thumbs?['medium']?['url']?.toString() ?? '';
              final count = int.tryParse(p['contentDetails']?['itemCount']?.toString() ?? '0') ?? 0;

              playlists.add(Playlist(
                id: plId,
                title: title,
                subtitle: '$count brani',
                coverUrl: AppConfig.formatArtwork(rawThumb),
                tracks: [],
              ));
            }
          }
        } catch (_) {}
      }
    }

    return {
      'user': user,
      'likedSongs': likedSongs,
      'playlists': playlists,
    };
  }

  // --- Parsing Helpers ---
  Track? _parseTrackFromItem(Map item) {
    try {
      final twoRow = item['musicTwoRowItemRenderer'] as Map? ?? (item.containsKey('title') && item.containsKey('navigationEndpoint') ? item : null);
      final responsive = item['musicResponsiveListItemRenderer'] as Map? ?? (item.containsKey('flexColumns') ? item : null);
      final panelVideo = item['playlistPanelVideoRenderer'] as Map? ?? (item.containsKey('shortBylineText') && item.containsKey('videoId') ? item : null);

      if (twoRow != null) {
        var title = twoRow['title']?['runs']?[0]?['text']?.toString() ?? '';
        final subtitleRuns = twoRow['subtitle']?['runs'] as List? ?? [];
        String artist = '';
        String artistId = '';

        for (final r in subtitleRuns) {
          final browseId = (r as Map)['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';
          if (browseId.startsWith('UC') || browseId.startsWith('FEmusic_library')) {
            artistId = browseId;
            artist = r['text']?.toString() ?? '';
            break;
          }
        }

        if (artist.isEmpty) {
          for (final r in subtitleRuns) {
            final t = (r as Map)['text']?.toString() ?? '';
            if (t == 'Brano' || t == 'Video' || t == 'Song' || t == ' • ' || t == ' e ' || t == ' & ' || t.contains(':') || t.contains('visualizzazioni') || t.contains('views') || t.contains('riproduzioni') || t.contains('ascoltatori')) continue;
            artist = t;
            break;
          }
        }

        if ((artist.isEmpty || artist.toLowerCase() == 'artista') && title.contains(' - ')) {
          final parts = title.split(' - ');
          if (parts.length >= 2 && parts[0].trim().isNotEmpty) {
            artist = parts[0].trim();
            title = parts.sublist(1).join(' - ').trim();
          }
        }

        final vId = twoRow['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString() ??
                    twoRow['thumbnailOverlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId']?.toString() ?? '';
        final thumbs = (twoRow['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
                        twoRow['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
        final thumb = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : '';

        if (title.isNotEmpty && vId.isNotEmpty) {
          return Track(
            id: vId,
            videoId: vId,
            title: title,
            artistName: AppConfig.sanitizeArtist(artist.isNotEmpty ? artist : 'Artista'),
            artistId: artistId,
            coverUrl: AppConfig.formatArtwork(thumb),
            durationMs: 210000,
          );
        }
      } else if (responsive != null) {
        final flexCols = responsive['flexColumns'] as List? ?? [];
        final col0 = flexCols.isNotEmpty ? (flexCols[0] as Map)['musicResponsiveListItemFlexColumnRenderer'] : null;
        final col1 = flexCols.length > 1 ? (flexCols[1] as Map)['musicResponsiveListItemFlexColumnRenderer'] : null;
        var title = col0?['text']?['runs']?[0]?['text']?.toString() ?? '';
        final artistRuns = col1?['text']?['runs'] as List? ?? [];

        String artist = '';
        String artistId = '';

        for (final r in artistRuns) {
          final browseId = (r as Map)['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';
          if (browseId.startsWith('UC') || browseId.startsWith('FEmusic_library')) {
            artistId = browseId;
            artist = r['text']?.toString() ?? '';
            break;
          }
        }

        if (artist.isEmpty) {
          for (final r in artistRuns) {
            final t = (r as Map)['text']?.toString() ?? '';
            if (t == 'Brano' || t == 'Video' || t == 'Song' || t == ' • ' || t == ' e ' || t == ' & ' || t.contains(':') || t.contains('visualizzazioni') || t.contains('views') || t.contains('riproduzioni') || t.contains('ascoltatori')) continue;
            artist = t;
            break;
          }
        }

        if (artist.isEmpty && flexCols.length > 2) {
          for (int c = 2; c < flexCols.length; c++) {
            final otherRuns = (flexCols[c] as Map)['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List? ?? [];
            for (final r in otherRuns) {
              final browseId = (r as Map)['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';
              if (browseId.startsWith('UC') || browseId.startsWith('FEmusic_library')) {
                artistId = browseId;
                artist = r['text']?.toString() ?? '';
                break;
              }
            }
            if (artist.isNotEmpty) break;
          }
        }

        if ((artist.isEmpty || artist.toLowerCase() == 'artista') && title.contains(' - ')) {
          final parts = title.split(' - ');
          if (parts.length >= 2 && parts[0].trim().isNotEmpty) {
            artist = parts[0].trim();
            title = parts.sublist(1).join(' - ').trim();
          }
        }

        String albumName = '';
        String albumId = '';
        int durationMs = 210000;

        for (final col in flexCols) {
          final runs = (col as Map)['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List? ?? [];
          for (final r in runs) {
            final ep = (r as Map)['navigationEndpoint']?['browseEndpoint'];
            final pageType = ep?['browseEndpointContextSupportedConfigs']?['browseEndpointContextMusicConfig']?['pageType']?.toString() ?? '';
            final bId = ep?['browseId']?.toString() ?? '';
            if (pageType == 'MUSIC_PAGE_TYPE_ALBUM' || bId.startsWith('MPREb_')) {
              albumId = bId;
              albumName = r['text']?.toString() ?? '';
            }
          }
        }

        final fixedCols = responsive['fixedColumns'] as List? ?? [];
        if (fixedCols.isNotEmpty) {
          final durText = (fixedCols[0] as Map)['musicResponsiveListItemFixedColumnRenderer']?['text']?['runs']?[0]?['text']?.toString();
          if (durText != null) {
            final parts = durText.split(':').map((s) => int.tryParse(s) ?? 0).toList();
            if (parts.length == 2) {
              durationMs = (parts[0] * 60 + parts[1]) * 1000;
            } else if (parts.length == 3) {
              durationMs = (parts[0] * 3600 + parts[1] * 60 + parts[2]) * 1000;
            }
          }
        }

        String vId = responsive['playlistItemData']?['videoId']?.toString() ??
                    responsive['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId']?.toString() ??
                    col0?['text']?['runs']?[0]?['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString() ??
                    responsive['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString() ?? '';

        if (vId.isEmpty) {
          for (final col in flexCols) {
            final runs = (col as Map)['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List? ?? [];
            for (final r in runs) {
              final ep = (r as Map)['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString();
              if (ep != null && ep.isNotEmpty) {
                vId = ep;
                break;
              }
            }
            if (vId.isNotEmpty) break;
          }
        }

        if (vId.isEmpty) {
          void findVId(dynamic node) {
            if (vId.isNotEmpty) return;
            if (node is Map) {
              if (node.containsKey('videoId') && node['videoId'] is String && (node['videoId'] as String).isNotEmpty) {
                vId = node['videoId'] as String;
                return;
              }
              for (final v in node.values) {
                findVId(v);
              }
            } else if (node is List) {
              for (final e in node) {
                findVId(e);
              }
            }
          }
          findVId(responsive);
        }

        final thumbs = (responsive['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
                        responsive['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
        final thumb = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : '';

        if (title.isNotEmpty && vId.isNotEmpty) {
          return Track(
            id: vId,
            videoId: vId,
            title: title,
            artistName: AppConfig.sanitizeArtist(artist.isNotEmpty ? artist : 'Artista'),
            artistId: artistId,
            albumName: albumName,
            albumId: albumId,
            coverUrl: AppConfig.formatArtwork(thumb),
            durationMs: durationMs,
          );
        }
      } else if (panelVideo != null) {
        final vId = panelVideo['videoId']?.toString() ?? '';
        final title = panelVideo['title']?['runs']?[0]?['text']?.toString() ?? '';
        final shortArtist = ((panelVideo['shortBylineText']?['runs'] as List?) ?? []).map((r) => r['text']).join('');
        String artistId = '';
        String albumName = '';
        String albumId = '';
        final longRuns = (panelVideo['longBylineText']?['runs'] as List?) ?? [];
        for (final run in longRuns) {
          final endpoint = run['navigationEndpoint']?['browseEndpoint'];
          final pageType = endpoint?['browseEndpointContextSupportedConfigs']?['browseEndpointContextMusicConfig']?['pageType']?.toString() ?? '';
          if (pageType == 'MUSIC_PAGE_TYPE_ARTIST') {
            artistId = endpoint?['browseId']?.toString() ?? '';
          } else if (pageType == 'MUSIC_PAGE_TYPE_ALBUM') {
            albumId = endpoint?['browseId']?.toString() ?? '';
            albumName = run['text']?.toString() ?? '';
          }
        }
        final thumb = _extractLargestThumbnail(panelVideo['thumbnail']);
        int durationMs = 210000;
        final durText = panelVideo['lengthText']?['runs']?[0]?['text']?.toString();
        if (durText != null) {
          final parts = durText.split(':').map((s) => int.tryParse(s) ?? 0).toList();
          if (parts.length == 2) {
            durationMs = (parts[0] * 60 + parts[1]) * 1000;
          } else if (parts.length == 3) {
            durationMs = (parts[0] * 3600 + parts[1] * 60 + parts[2]) * 1000;
          }
        }
        if (title.isNotEmpty && vId.isNotEmpty) {
          return Track(
            id: vId,
            videoId: vId,
            title: title,
            artistName: AppConfig.sanitizeArtist(shortArtist.isNotEmpty ? shortArtist : 'Artista'),
            artistId: artistId,
            albumName: albumName,
            albumId: albumId,
            coverUrl: AppConfig.formatArtwork(thumb),
            durationMs: durationMs,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Artist? _parseArtistFromItem(Map item) {
    try {
      final resp = item['musicResponsiveListItemRenderer'] as Map? ?? item['musicTwoRowItemRenderer'] as Map? ?? (item.containsKey('title') ? item : null);
      if (resp != null) {
        final flexCols = resp['flexColumns'] as List? ?? [];
        final col0 = flexCols.isNotEmpty ? (flexCols[0] as Map)['musicResponsiveListItemFlexColumnRenderer'] : null;
        final browseId = resp['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ??
                         col0?['text']?['runs']?[0]?['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';
        final title = resp['title']?['runs']?[0]?['text']?.toString() ?? col0?['text']?['runs']?[0]?['text']?.toString() ?? '';
        final thumbs = (resp['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ?? resp['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
        final thumb = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : '';

        final nav = resp['navigationEndpoint'] ?? col0?['text']?['runs']?[0]?['navigationEndpoint'];
        final pageType = nav?['browseEndpoint']?['browseEndpointContextSupportedConfigs']?['browseEndpointContextMusicConfig']?['pageType']?.toString() ?? '';
        final subtitleRuns = (resp['subtitle']?['runs'] as List?) ?? [];
        final subtitleText = subtitleRuns.map((r) => (r as Map)['text']).join('').toLowerCase();
        final isArtist = pageType == 'MUSIC_PAGE_TYPE_ARTIST' || subtitleText.contains('artist') || subtitleText.contains('artista');

        if (browseId.startsWith('UC') || browseId.startsWith('FEmusic_library') || (isArtist && title.isNotEmpty)) {
          return Artist(
            id: browseId.isNotEmpty ? browseId : title,
            name: AppConfig.sanitizeArtist(title),
            picture: AppConfig.formatArtwork(thumb),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Album? _parseAlbumFromItem(Map item) {
    try {
      final resp = item['musicResponsiveListItemRenderer'] as Map? ?? item['musicTwoRowItemRenderer'] as Map? ?? (item.containsKey('title') ? item : null);
      if (resp != null) {
        final flexCols = resp['flexColumns'] as List? ?? [];
        final col0 = flexCols.isNotEmpty ? (flexCols[0] as Map)['musicResponsiveListItemFlexColumnRenderer'] : null;
        final col1 = flexCols.length > 1 ? (flexCols[1] as Map)['musicResponsiveListItemFlexColumnRenderer'] : null;
        final browseId = resp['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ??
                         col0?['text']?['runs']?[0]?['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';
        final title = resp['title']?['runs']?[0]?['text']?.toString() ?? col0?['text']?['runs']?[0]?['text']?.toString() ?? '';
        
        String artist = '';
        String artistId = '';
        String year = '';
        final runs = (col1?['text']?['runs'] as List?) ?? (resp['subtitle']?['runs'] as List?) ?? [];
        for (final r in runs) {
          final t = (r as Map)['text']?.toString() ?? '';
          final bId = r['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';
          if (bId.startsWith('UC')) {
            artistId = bId;
            artist = t;
          }
          final yMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(t);
          if (yMatch != null) {
            year = yMatch.group(1) ?? '';
          }
        }
        if (artist.isEmpty) {
          for (final r in runs) {
            final t = (r as Map)['text']?.toString() ?? '';
            if (t != 'Album' && t != 'Singolo' && t != 'EP' && t != ' • ' && !t.contains('19') && !t.contains('20')) {
              artist = t;
              break;
            }
          }
        }

        String type = 'Album';
        for (final r in runs) {
          final t = ((r as Map)['text']?.toString() ?? '').toLowerCase();
          if (t.contains('singol') || t.contains('single')) {
            type = 'Single';
            break;
          } else if (t.contains('ep')) {
            type = 'EP';
            break;
          } else if (t.contains('album')) {
            type = 'Album';
            break;
          }
        }

        final thumbs = (resp['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ?? resp['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
        final thumb = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : '';

        if (browseId.startsWith('MPREb_') || browseId.startsWith('OLAK5uy_')) {
          return Album(
            id: browseId,
            title: title,
            artistName: AppConfig.sanitizeArtist(artist.isNotEmpty ? artist : 'Artista'),
            artistId: artistId,
            coverUrl: AppConfig.formatArtwork(thumb),
            year: year,
            type: type,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Playlist? _parsePlaylistFromItem(Map item) {
    try {
      final twoRow = item['musicTwoRowItemRenderer'] as Map? ?? item['musicResponsiveListItemRenderer'] as Map? ?? (item.containsKey('title') ? item : null);
      if (twoRow != null) {
        final title = twoRow['title']?['runs']?[0]?['text']?.toString() ?? '';
        final subtitleRuns = twoRow['subtitle']?['runs'] as List? ?? [];
        final subtitle = subtitleRuns.map((r) => r['text']).join('');
        
        String browseId = twoRow['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';
        if (browseId.isEmpty) {
          final flexCols = twoRow['flexColumns'] as List? ?? [];
          if (flexCols.isNotEmpty) {
            final col0 = (flexCols[0] as Map)['musicResponsiveListItemFlexColumnRenderer'];
            browseId = col0?['text']?['runs']?[0]?['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';
          }
        }

        final thumbs = (twoRow['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
                        twoRow['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
        final thumb = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : '';

        if (browseId.startsWith('VL') || browseId.startsWith('PL') || browseId.startsWith('RD') || browseId.contains('playlist') || browseId.startsWith('FEmusic_liked')) {
          final cleanId = browseId.startsWith('VL') ? browseId.substring(2) : browseId;
          return Playlist(
            id: cleanId,
            title: title.isNotEmpty ? title : 'Playlist',
            subtitle: subtitle,
            coverUrl: AppConfig.formatArtwork(thumb),
            tracks: [],
          );
        }
      }
    } catch (_) {}
    return null;
  }

  List<Track> _getFallbackPicks() {
    return [
      Track(
        id: '5oRc6oqn4nA',
        videoId: '5oRc6oqn4nA',
        title: 'CASINI',
        artistName: 'Marracash & Guè',
        coverUrl: 'https://i.ytimg.com/vi/5oRc6oqn4nA/hqdefault.jpg',
        durationMs: 188000,
      ),
      Track(
        id: 'Wyvs_ZHVrIA',
        videoId: 'Wyvs_ZHVrIA',
        title: 'Giovani Re',
        artistName: 'Sfera Ebbasta',
        coverUrl: 'https://i.ytimg.com/vi/Wyvs_ZHVrIA/hqdefault.jpg',
        durationMs: 195000,
      ),
      Track(
        id: 'SiCaaA84RFU',
        videoId: 'SiCaaA84RFU',
        title: 'MERAVIGLIOSO ERRORE',
        artistName: 'Gianna Nannini',
        coverUrl: 'https://i.ytimg.com/vi/SiCaaA84RFU/hqdefault.jpg',
        durationMs: 210000,
      ),
      Track(
        id: 'kJQP7kiw5Fk',
        videoId: 'kJQP7kiw5Fk',
        title: 'Despacito',
        artistName: 'Luis Fonsi ft. Daddy Yankee',
        coverUrl: 'https://i.ytimg.com/vi/kJQP7kiw5Fk/hqdefault.jpg',
        durationMs: 282000,
      ),
    ];
  }
}
