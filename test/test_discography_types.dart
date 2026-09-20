import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:preluded_music/models/album.dart';
import 'package:preluded_music/models/playlist.dart';
import 'package:preluded_music/models/artist.dart';

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  test('Test categorization of Discography for multiple artists', () async {
    HttpOverrides.global = _RealHttpOverrides();
    final client = http.Client();

    final testArtists = [
      {'name': 'BLANCO', 'id': 'UC3cvw22UbTYbH63m_9a_tAQ'},
      {'name': 'Marracash', 'id': 'UCqnCDXGWUGDV8ONQqMIWZ7A'},
    ];

    for (final a in testArtists) {
      final uri = Uri.parse('https://music.youtube.com/youtubei/v1/browse?prettyPrint=false');
      final payload = jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240101.01.00',
            'hl': 'it',
            'gl': 'IT',
          }
        },
        'browseId': a['id'],
      });

      final res = await client.post(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Origin': 'https://music.youtube.com',
        'Referer': 'https://music.youtube.com/',
        'Content-Type': 'application/json',
      }, body: payload);

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      void findNodes(dynamic node, String key, List results) {
        if (node is Map) {
          if (node.containsKey(key)) results.add(node[key]);
          for (final v in node.values) findNodes(v, key, results);
        } else if (node is List) {
          for (final e in node) findNodes(e, key, results);
        }
      }

      final carousels = <dynamic>[];
      findNodes(data, 'musicCarouselShelfRenderer', carousels);

      final albums = <Map<String, dynamic>>[];
      final singles = <Map<String, dynamic>>[];
      final playlists = <Map<String, dynamic>>[];

      for (final c in carousels) {
        final cTitle = (c['header']?['musicCarouselShelfBasicHeaderRenderer']?['title']?['runs']?[0]?['text'] ?? '').toString().toLowerCase();
        final items = <dynamic>[];
        findNodes(c, 'musicTwoRowItemRenderer', items);

        for (final it in items) {
          final title = it['title']?['runs']?[0]?['text']?.toString() ?? '';
          final subRuns = it['subtitle']?['runs'] as List? ?? [];
          final subText = subRuns.map((r) => r['text']).join('');
          final subLower = subText.toLowerCase();
          final bId = it['navigationEndpoint']?['browseEndpoint']?['browseId']?.toString() ?? '';

          if (bId.startsWith('UC')) {
            // Artist, ignore
            continue;
          }

          if (bId.startsWith('VL') || bId.startsWith('PL') || subLower.contains('playlist') || cTitle.contains('playlist') || cTitle.contains('primo piano') || cTitle.contains('featured')) {
            playlists.add({'title': title, 'sub': subText, 'id': bId, 'carousel': cTitle});
          } else if (cTitle.contains('singol') || cTitle.contains('single') || cTitle.contains('ep') || subLower.contains('singol') || subLower.contains('single') || subLower.contains('ep')) {
            singles.add({'title': title, 'sub': subText, 'id': bId, 'carousel': cTitle});
          } else if (cTitle.contains('album') || subLower.contains('album') || bId.startsWith('MPREb_') || bId.startsWith('OLAK5uy_')) {
            albums.add({'title': title, 'sub': subText, 'id': bId, 'carousel': cTitle});
          }
        }
      }

      print('=== ARTIST: ${a['name']} ===');
      print('Albums (${albums.length}):');
      for (final alb in albums) {
        print('  [ALBUM] ${alb['title']} (${alb['sub']})');
      }
      print('Singles & EPs (${singles.length}):');
      for (final s in singles.take(5)) {
        print('  [SINGLE] ${s['title']} (${s['sub']})');
      }
      print('Playlists (${playlists.length}):');
      for (final p in playlists.take(5)) {
        print('  [PLAYLIST] ${p['title']} (${p['sub']})');
      }
      print('');
    }
  });
}

