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
            if (k.isNotEmpty && !cookieMap.containsKey(k)) {
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
  Future<List<Track>> fetchQuickPicks({int limit = 20}) async {
    // 1. If cookies are present, try fetching user listening history first!
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
            print('[ApiService] fetchQuickPicks loaded ${historyTracks.length} tracks from FEmusic_history');
            return historyTracks.take(limit).toList();
          }
        }
      } catch (e) {
        print('[ApiService] History quick picks error: $e');
      }
    }

    // 2. Otherwise/Fallback: Fetch from FEmusic_home shelves
    try {
      final uri = Uri.parse('$_innertubeEndpoint/browse?prettyPrint=false');
      final payload = jsonEncode({
        'context': _buildClientContext(),
        'browseId': 'FEmusic_home',
      });

      final res = await _client.post(uri, headers: _buildInnertubeHeaders(), body: payload).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final carouselShelves = _findNodes(data, 'musicCarouselShelfRenderer');
        final standardShelves = _findNodes(data, 'musicShelfRenderer');
        final allShelves = [...carouselShelves, ...standardShelves];

        final tracks = <Track>[];

        // Try personalized shelves first
        for (final shelf in allShelves) {
          final title = shelf['header']?['musicCarouselShelfBasicHeaderRenderer']?['title']?['runs']?[0]?['text']?.toString() ??
                        shelf['header']?['musicShelfBasicHeaderRenderer']?['title']?['runs']?[0]?['text']?.toString() ?? '';
          final titleLower = title.toLowerCase();
          final isPersonalized = titleLower.contains('ascolta') ||
                                 titleLower.contains('preferit') ||
                                 titleLower.contains('scelt') ||
                                 titleLower.contains('quick') ||
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

        // If no matching titled shelf, take the first shelf with items
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
    return _getFallbackPicks();
  }

  // --- 2. Home Feed Shelves ---
  Future<Map<String, List<Track>>> fetchHomeSections() async {
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
        params = 'EgWKAQIIAWoQEAMQBBAJEAoQCxAEEAkQChAA';
      } else if (filter == 'albums') {
        params = 'EgWKAQIBAmoQEAMQBBAJEAoQCxAEEAkQChAA';
      } else if (filter == 'artists') {
        params = 'EgWKAQIIAmoQEAMQBBAJEAoQCxAEEAkQChAA';
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

        // 1. Process card shelf (Top result artist & top tracks)
        final cardShelves = _findNodes(data, 'musicCardShelfRenderer');
        String cardArtistName = '';
        for (final card in cardShelves) {
          final title = card['title']?['runs']?[0]?['text']?.toString() ?? '';
          final browseId = card['title']?['runs']?[0]?['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';
          final thumbs = (card['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
          final thumb = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : '';
          if (title.isNotEmpty && browseId.isNotEmpty) {
            cardArtistName = title;
            if (!artists.any((a) => a.id == browseId)) {
              artists.add(Artist(id: browseId, name: AppConfig.sanitizeArtist(title), picture: AppConfig.formatArtwork(thumb)));
            }
          }
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

        // 2. Process all responsive items across all 30+ sections
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
          final thumb = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : '';

          final subLower = subFull.toLowerCase();
          final isArtist = pageType == 'MUSIC_PAGE_TYPE_ARTIST' || subLower.startsWith('artista') || subLower.startsWith('artist');
          final isAlbum = pageType == 'MUSIC_PAGE_TYPE_ALBUM' || subLower.startsWith('album') || subLower.startsWith('singolo') || subLower.startsWith('ep');
          final isPlaylist = pageType == 'MUSIC_PAGE_TYPE_PLAYLIST' || subLower.startsWith('playlist');
          final isTrack = vId.isNotEmpty || subLower.startsWith('brano') || subLower.startsWith('canzone') || subLower.startsWith('song') || subLower.startsWith('video');

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

            if (!tracks.any((t) => t.id == vId)) {
              tracks.add(Track(
                id: vId,
                videoId: vId,
                title: title,
                artistName: AppConfig.sanitizeArtist(trackArtist),
                coverUrl: AppConfig.formatArtwork(thumb),
                durationMs: 210000,
              ));
            }
          }
        }

        // 3. Process all two-row items
        final twoRowNodes = _findNodes(data, 'musicTwoRowItemRenderer');
        for (final node in twoRowNodes) {
          final t = _parseTrackFromItem(node);
          if (t != null && !tracks.any((x) => x.id == t.id)) {
            tracks.add(t);
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
      final title = track.title;
      final artist = track.artistName;
      final durSec = track.durationMs ~/ 1000;

      final uri = Uri.parse(
        'https://lrclib.net/api/get?track_name=${Uri.encodeComponent(title)}&artist_name=${Uri.encodeComponent(artist)}&duration=$durSec',
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

      // Search fallback on LRCLib
      final searchUri = Uri.parse('https://lrclib.net/api/search?q=${Uri.encodeComponent('$title $artist')}');
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

      final res = await _client.post(uri, headers: _buildInnertubeHeaders(), body: payload).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final playlist = data['contents']?['singleColumnMusicWatchNextResultsRenderer']?['tabbedRenderer']?['watchNextTabbedResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['musicQueueRenderer']?['content']?['playlistPanelRenderer']?['contents'] as List? ?? [];
        
        final tracks = <Track>[];
        for (final item in playlist) {
          final renderer = (item as Map)['playlistPanelVideoRenderer'] as Map?;
          if (renderer != null) {
            final tId = renderer['videoId']?.toString() ?? '';
            final title = renderer['title']?['runs']?[0]?['text']?.toString() ?? '';
            final artist = ((renderer['shortBylineText']?['runs'] as List?) ?? []).map((r) => r['text']).join('');
            final thumbs = renderer['thumbnail']?['thumbnails'] as List? ?? [];
            final thumb = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : '';

            if (tId.isNotEmpty && title.isNotEmpty && tId != vId) {
              tracks.add(Track(
                id: tId,
                videoId: tId,
                title: title,
                artistName: AppConfig.sanitizeArtist(artist),
                coverUrl: AppConfig.formatArtwork(thumb),
                durationMs: 210000,
              ));
            }
          }
        }
        if (tracks.isNotEmpty) return tracks;
      }
    } catch (e) {
      print('ApiService fetchMix error: $e');
    }
    return [];
  }

  // --- 7. Artist Details ---
  Future<Artist?> fetchArtist(String artistId) async {
    try {
      final uri = Uri.parse('$_innertubeEndpoint/browse?prettyPrint=false');
      final payload = jsonEncode({
        'context': _buildClientContext(),
        'browseId': artistId,
      });

      final res = await _client.post(uri, headers: _buildInnertubeHeaders(), body: payload).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final header = data['header']?['musicImmersiveHeaderRenderer'] ??
                       data['header']?['musicVisualHeaderRenderer'] ??
                       data['header']?['musicResponsiveHeaderRenderer'];
        final name = header?['title']?['runs']?[0]?['text']?.toString() ?? 'Artista';
        final thumbs = (header?['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
                        header?['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
        final thumb = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : '';
        final desc = header?['description']?['runs']?[0]?['text']?.toString() ?? '';

        // Extract top tracks
        final rawTracks = _findNodes(data, 'musicResponsiveListItemRenderer');
        final topTracks = <Track>[];
        for (final item in rawTracks) {
          final t = _parseTrackFromItem(item);
          if (t != null) {
            topTracks.add(t.copyWith(
              artistName: t.artistName == 'Artista' || t.artistName.isEmpty ? name : t.artistName,
            ));
          }
        }

        // Extract albums and singles
        final rawAlbums = _findNodes(data, 'musicTwoRowItemRenderer');
        final albums = <Album>[];
        for (final item in rawAlbums) {
          final al = _parseAlbumFromTwoRow(item, name);
          if (al != null && !albums.any((a) => a.id == al.id)) {
            albums.add(al);
          }
        }

        return Artist(
          id: artistId,
          name: AppConfig.sanitizeArtist(name),
          picture: AppConfig.formatArtwork(thumb),
          bio: desc,
          topTracks: topTracks,
          albums: albums,
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
      final uri = Uri.parse('$_innertubeEndpoint/browse?prettyPrint=false');
      final payload = jsonEncode({
        'context': _buildClientContext(),
        'browseId': albumId,
      });

      final res = await _client.post(uri, headers: _buildInnertubeHeaders(), body: payload).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final header = data['header']?['musicDetailHeaderRenderer'] ??
                       data['header']?['musicResponsiveHeaderRenderer'];
        final title = header?['title']?['runs']?[0]?['text']?.toString() ?? 'Album';
        final artist = header?['straplineTextOne']?['runs']?[0]?['text']?.toString() ??
                       header?['subtitle']?['runs']?[0]?['text']?.toString() ?? 'Artista';
        final subRuns = header?['subtitle']?['runs'] as List? ?? [];
        String year = '';
        for (final r in subRuns) {
          final txt = r['text']?.toString() ?? '';
          if (txt.contains('202') || txt.contains('201') || txt.contains('199') || txt.contains('198')) {
            year = txt;
            break;
          }
        }
        final thumbs = (header?['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
                        header?['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
        final cover = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : '';

        final rawTracks = _findNodes(data, 'musicResponsiveListItemRenderer');
        final tracks = <Track>[];
        for (final item in rawTracks) {
          final t = _parseTrackFromItem(item);
          if (t != null) {
            tracks.add(t.copyWith(
              albumName: title,
              artistName: t.artistName == 'Artista' || t.artistName.isEmpty ? artist : t.artistName,
              coverUrl: t.coverUrl.isEmpty ? cover : t.coverUrl,
            ));
          }
        }

        return Album(
          id: albumId,
          title: title,
          artistName: AppConfig.sanitizeArtist(artist),
          coverUrl: AppConfig.formatArtwork(cover),
          year: year,
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

  Album? _parseAlbumFromTwoRow(Map item, String defaultArtist) {
    try {
      final renderer = item['musicTwoRowItemRenderer'] ?? item;
      final nav = renderer['navigationEndpoint'] ?? renderer['title']?['runs']?[0]?['navigationEndpoint'];
      final bId = nav?['browseEndpoint']?['browseId']?.toString();
      if (bId == null || bId.isEmpty) return null;

      final title = renderer['title']?['runs']?[0]?['text']?.toString() ?? 'Album';
      final thumbs = (renderer['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
                      renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
      final thumb = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : '';

      final subRuns = renderer['subtitle']?['runs'] as List? ?? [];
      String year = '';
      for (final r in subRuns) {
        final txt = r['text']?.toString() ?? '';
        if (txt.contains('202') || txt.contains('201') || txt.contains('199') || txt.contains('198')) {
          year = txt;
          break;
        }
      }

      return Album(
        id: bId,
        title: title,
        artistName: defaultArtist,
        coverUrl: AppConfig.formatArtwork(thumb),
        year: year,
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

      final headers = _buildInnertubeHeaders();
      headers['Cookie'] = cookieString;
      final auth = _generateSapisidHash(cookieString);
      if (auth != null) headers['Authorization'] = auth;

      final res = await _client.post(uri, headers: headers, body: payload).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final actions = data['actions'] as List? ?? [];
        if (actions.isNotEmpty) {
          final header = actions[0]?['openPopupAction']?['popup']?['multiPageMenuRenderer']?['header']?['activeAccountHeaderRenderer'];
          if (header != null) {
            final name = header['accountName']?['runs']?[0]?['text']?.toString() ?? 'Utente Google';
            final email = header['email']?['runs']?[0]?['text']?.toString() ?? '';
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

      // 1.2 Playlists via Innertube (Try FEmusic_liked_playlists, FEmusic_library_landing)
      for (final plBrowseId in ['FEmusic_liked_playlists', 'FEmusic_library_landing']) {
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
            if (playlists.isNotEmpty) {
              break;
            }
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

      if (twoRow != null) {
        final title = twoRow['title']?['runs']?[0]?['text']?.toString() ?? '';
        final subtitleRuns = twoRow['subtitle']?['runs'] as List? ?? [];
        final artistCandidates = <String>[];
        for (final r in subtitleRuns) {
          final t = r['text']?.toString() ?? '';
          if (t == 'Brano' || t == 'Video' || t == 'Song' || t == ' • ' || t == ' e ' || t == ' & ' || t.contains(':') || t.contains('visualizzazioni') || t.contains('views') || t.contains('riproduzioni') || t.contains('ascoltatori')) continue;
          artistCandidates.add(t);
        }
        final artist = artistCandidates.isNotEmpty ? artistCandidates.join(', ') : subtitleRuns.map((r) => r['text']).join('');
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
            coverUrl: AppConfig.formatArtwork(thumb),
            durationMs: 210000,
          );
        }
      } else if (responsive != null) {
        final flexCols = responsive['flexColumns'] as List? ?? [];
        final col0 = flexCols.isNotEmpty ? (flexCols[0] as Map)['musicResponsiveListItemFlexColumnRenderer'] : null;
        final col1 = flexCols.length > 1 ? (flexCols[1] as Map)['musicResponsiveListItemFlexColumnRenderer'] : null;
        final title = col0?['text']?['runs']?[0]?['text']?.toString() ?? '';
        final artistRuns = col1?['text']?['runs'] as List? ?? [];
        final artistCandidates = <String>[];
        for (final r in artistRuns) {
          final t = r['text']?.toString() ?? '';
          if (t == 'Brano' || t == 'Video' || t == 'Song' || t == ' • ' || t == ' e ' || t == ' & ' || t.contains(':') || t.contains('visualizzazioni') || t.contains('views') || t.contains('riproduzioni') || t.contains('ascoltatori')) continue;
          artistCandidates.add(t);
        }
        final artist = artistCandidates.isNotEmpty ? artistCandidates.join(', ') : artistRuns.map((r) => r['text']).join('');

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

        final thumbs = (responsive['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
                        responsive['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
        final thumb = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : '';

        if (title.isNotEmpty && vId.isNotEmpty) {
          return Track(
            id: vId,
            videoId: vId,
            title: title,
            artistName: AppConfig.sanitizeArtist(artist.isNotEmpty ? artist : 'Artista'),
            coverUrl: AppConfig.formatArtwork(thumb),
            durationMs: 210000,
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

        if (browseId.startsWith('UC') || browseId.startsWith('FEmusic_library_privately_owned_artist')) {
          return Artist(
            id: browseId,
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
        final artist = ((col1?['text']?['runs'] as List?) ?? []).map((r) => r['text']).join('');
        final thumbs = (resp['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ?? resp['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
        final thumb = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : '';

        if (browseId.startsWith('MPREb_') || browseId.startsWith('OLAK5uy_')) {
          return Album(
            id: browseId,
            title: title,
            artistName: AppConfig.sanitizeArtist(artist),
            coverUrl: AppConfig.formatArtwork(thumb),
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
