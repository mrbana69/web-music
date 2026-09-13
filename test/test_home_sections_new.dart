import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:preluded_music/config/app_config.dart';
import 'package:preluded_music/models/track.dart';

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
      
      final runs1 = col1?['text']?['runs'] as List? ?? [];
      final artistCandidates = <String>[];
      for (final r in runs1) {
        final t = r['text']?.toString() ?? '';
        if (t == 'Brano' || t == 'Video' || t == 'Song' || t == ' • ' || t == ' e ' || t == ' & ' || t.contains(':') || t.contains('visualizzazioni') || t.contains('views') || t.contains('riproduzioni') || t.contains('ascoltatori')) continue;
        artistCandidates.add(t);
      }
      final artist = artistCandidates.isNotEmpty ? artistCandidates.join(', ') : runs1.map((r) => r['text']).join('');

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

void main() async {
  final client = http.Client();
  final uri = Uri.parse('https://music.youtube.com/youtubei/v1/browse?prettyPrint=false');
  final payload = jsonEncode({
    'context': {
      'client': {'clientName': 'WEB_REMIX', 'clientVersion': '1.20241101.01.00', 'hl': 'it', 'gl': 'IT'},
      'user': {},
    },
    'browseId': 'FEmusic_home',
  });
  final headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    'Origin': 'https://music.youtube.com',
  };

  final res = await client.post(uri, headers: headers, body: payload);
  final data = jsonDecode(res.body);

  final carouselShelves = findNodes(data, 'musicCarouselShelfRenderer');
  final standardShelves = findNodes(data, 'musicShelfRenderer');
  final allShelves = [...carouselShelves, ...standardShelves];

  final sections = <String, List<Track>>{};
  for (final shelf in allShelves) {
    final title = shelf['header']?['musicCarouselShelfBasicHeaderRenderer']?['title']?['runs']?[0]?['text']?.toString() ??
                  shelf['header']?['musicShelfBasicHeaderRenderer']?['title']?['runs']?[0]?['text']?.toString() ?? '';
    if (title.isEmpty) continue;

    final contents = shelf['contents'] as List? ?? [];
    final items = <Track>[];
    for (final item in contents) {
      final track = parseTrackFromItem(item as Map);
      if (track != null && !items.any((t) => t.id == track.id)) {
        items.add(track);
      }
    }
    if (items.isNotEmpty) {
      sections[title] = items;
    }
  }

  print('Loaded ${sections.length} sections:');
  sections.forEach((k, v) {
    print('  Section "$k": ${v.length} tracks');
    for (final t in v.take(3)) {
      print('    - ${t.title} (${t.artistName})');
    }
  });

  client.close();
}

