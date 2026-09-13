import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:preluded_music/config/app_config.dart';
import 'package:preluded_music/models/track.dart';
import 'package:preluded_music/models/artist.dart';
import 'package:preluded_music/models/album.dart';

List<Map<String, dynamic>> findNodes(dynamic node, String key) {
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

Track? parseTrackFromItem(Map item) {
  try {
    final twoRow = item['musicTwoRowItemRenderer'] as Map? ?? (item.containsKey('title') && item.containsKey('navigationEndpoint') ? item : null);
    final responsive = item['musicResponsiveListItemRenderer'] as Map? ?? (item.containsKey('flexColumns') ? item : null);

    if (twoRow != null) {
      final title = twoRow['title']?['runs']?[0]?['text']?.toString() ?? '';
      final subtitleRuns = twoRow['subtitle']?['runs'] as List? ?? [];
      final artist = subtitleRuns.map((r) => r['text']).join('');
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
          artistName: AppConfig.sanitizeArtist(artist),
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
      final artist = artistRuns.map((r) => r['text']).join('');

      String vId = responsive['playlistItemData']?['videoId']?.toString() ??
                  responsive['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId']?.toString() ??
                  col0?['text']?['runs']?[0]?['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString() ?? '';

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
          artistName: AppConfig.sanitizeArtist(artist),
          coverUrl: AppConfig.formatArtwork(thumb),
          durationMs: 210000,
        );
      }
    }
  } catch (_) {}
  return null;
}

Artist? parseArtistFromItem(Map item) {
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

Album? parseAlbumFromItem(Map item) {
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

void main() async {
  final client = http.Client();
  final uri = Uri.parse('https://music.youtube.com/youtubei/v1/search?prettyPrint=false');
  final payload = jsonEncode({
    'context': {
      'client': {'clientName': 'WEB_REMIX', 'clientVersion': '1.20241101.01.00', 'hl': 'it', 'gl': 'IT'},
      'user': {},
    },
    'query': 'Sfera Ebbasta',
  });
  final headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    'Origin': 'https://music.youtube.com',
  };
  final res = await client.post(uri, headers: headers, body: payload);
  final data = jsonDecode(res.body);
  final tracks = <Track>[];
  final artists = <Artist>[];
  final albums = <Album>[];

  // 1. Process card shelf (Top result)
  final cardShelves = findNodes(data, 'musicCardShelfRenderer');
  String cardArtistName = '';
  for (final card in cardShelves) {
    final title = card['title']?['runs']?[0]?['text']?.toString() ?? '';
    final browseId = card['title']?['runs']?[0]?['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';
    final thumbs = (card['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
    final thumb = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : '';
    if (title.isNotEmpty && browseId.isNotEmpty) {
      cardArtistName = title;
      artists.add(Artist(id: browseId, name: AppConfig.sanitizeArtist(title), picture: AppConfig.formatArtwork(thumb)));
    }
    final cardContents = card['contents'] as List? ?? [];
    for (final c in cardContents) {
      final r = c['musicResponsiveListItemRenderer'];
      if (r != null) {
        final flexCols = r['flexColumns'] as List? ?? [];
        final col0 = flexCols.isNotEmpty ? (flexCols[0] as Map)['musicResponsiveListItemFlexColumnRenderer'] : null;
        final songTitle = col0?['text']?['runs']?[0]?['text']?.toString() ?? '';
        final vId = col0?['text']?['runs']?[0]?['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString() ??
                    r['playlistItemData']?['videoId']?.toString() ??
                    r['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId']?.toString() ?? '';
        final cThumbs = (r['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
                         r['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
        final cThumb = cThumbs.isNotEmpty ? cThumbs.last['url']?.toString() : '';

        if (songTitle.isNotEmpty && vId.isNotEmpty) {
          tracks.add(Track(
            id: vId,
            videoId: vId,
            title: songTitle,
            artistName: AppConfig.sanitizeArtist(cardArtistName.isNotEmpty ? cardArtistName : 'Artista'),
            coverUrl: AppConfig.formatArtwork((cThumb?.isNotEmpty ?? false) ? cThumb! : thumb),
            durationMs: 210000,
          ));
        }
      }
    }
  }

  // 2. Process all responsive items
  final responsiveNodes = findNodes(data, 'musicResponsiveListItemRenderer');
  for (final node in responsiveNodes) {
    final flexCols = node['flexColumns'] as List? ?? [];
    if (flexCols.isEmpty) continue;
    final col0 = (flexCols[0] as Map)['musicResponsiveListItemFlexColumnRenderer'];
    final title = col0?['text']?['runs']?[0]?['text']?.toString() ?? '';
    if (title.isEmpty) continue;

    final col1 = flexCols.length > 1 ? (flexCols[1] as Map)['musicResponsiveListItemFlexColumnRenderer'] : null;
    final runs1 = (col1?['text']?['runs'] as List? ?? []);
    final subFull = runs1.map((r) => r['text']).join('');

    // Extract browseId and pageType
    final navEp = node['navigationEndpoint'] ?? col0?['text']?['runs']?[0]?['navigationEndpoint'];
    final browseId = navEp?['browseEndpoint']?['browseId']?.toString() ?? '';
    final pageType = navEp?['browseEndpoint']?['browseEndpointContextSupportedConfigs']?['browseEndpointContextMusicConfig']?['pageType']?.toString() ?? '';

    // Extract videoId
    String vId = navEp?['watchEndpoint']?['videoId']?.toString() ??
                 col0?['text']?['runs']?[0]?['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString() ??
                 node['playlistItemData']?['videoId']?.toString() ??
                 node['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId']?.toString() ?? '';

    final thumbs = (node['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] ??
                    node['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails']) as List? ?? [];
    final thumb = thumbs.isNotEmpty ? thumbs.last['url']?.toString() : '';

    // Determine type by pageType or subtitle runs
    final subLower = subFull.toLowerCase();
    final isArtist = pageType == 'MUSIC_PAGE_TYPE_ARTIST' || subLower.startsWith('artista') || subLower.startsWith('artist');
    final isAlbum = pageType == 'MUSIC_PAGE_TYPE_ALBUM' || subLower.startsWith('album') || subLower.startsWith('singolo') || subLower.startsWith('ep');
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
      // Find artist from runs1 (skip 'Album • ')
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
    } else if (isTrack) {
      if (vId.isEmpty) {
        print('Skipped track with empty vId: $title (sub: $subFull)');
        continue;
      }
      // Extract artist from runs1
      String trackArtist = '';
      final artistCandidates = <String>[];
      for (final r in runs1) {
        final t = r['text']?.toString() ?? '';
        if (t == 'Brano' || t == 'Video' || t == 'Song' || t == ' • ' || t == ' e ' || t == ' & ' || t.contains(':') || t.contains('visualizzazioni') || t.contains('views') || t.contains('riproduzioni')) continue;
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
    } else {
      print('Not matched: $title | $subFull | pageType=$pageType | vId=$vId');
    }
  }

  // 3. Check all two-row items
  final twoRowNodes = findNodes(data, 'musicTwoRowItemRenderer');
  for (final node in twoRowNodes) {
    final t = parseTrackFromItem(node);
    if (t != null && !tracks.any((x) => x.id == t.id)) {
      tracks.add(t);
      continue;
    }
    final art = parseArtistFromItem(node);
    if (art != null && !artists.any((x) => x.id == art.id)) {
      artists.add(art);
      continue;
    }
    final alb = parseAlbumFromItem(node);
    if (alb != null && !albums.any((x) => x.id == alb.id)) {
      albums.add(alb);
      continue;
    }
  }

  print('Tracks found: ${tracks.length}');
  for (final t in tracks.take(5)) {
    print('  Song: "${t.title}" by "${t.artistName}" (${t.id})');
  }
  print('Artists found: ${artists.length}');
  for (final a in artists) {
    print('  Artist: "${a.name}" (${a.id})');
  }
  print('Albums found: ${albums.length}');
  for (final al in albums) {
    print('  Album: "${al.title}" by "${al.artistName}" (${al.id})');
  }

  client.close();
}
