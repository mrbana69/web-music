import 'dart:convert';
import 'package:http/http.dart' as http;

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

void main() async {
  final client = http.Client();
  final uri = Uri.parse('https://music.youtube.com/youtubei/v1/browse?prettyPrint=false');

  final browseIds = [
    'FEmusic_home',
    'FEmusic_library_landing',
    'FEmusic_liked_playlists',
    'VLLM',
    'LM',
  ];

  for (final bId in browseIds) {
    final payload = jsonEncode({
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20241101.01.00',
          'hl': 'it',
          'gl': 'IT',
        }
      },
      'browseId': bId,
    });

    final headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
      'Origin': 'https://music.youtube.com',
      'Referer': 'https://music.youtube.com/',
      'X-YouTube-Client-Name': '67',
      'X-YouTube-Client-Version': '1.20241101.01.00',
    };

    final res = await client.post(uri, headers: headers, body: payload);
    print('\n--- $bId (Status: ${res.statusCode}) ---');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final tracks = findNodes(data, 'musicResponsiveListItemRenderer');
      final twoRow = findNodes(data, 'musicTwoRowItemRenderer');
      print('Found ${tracks.length} musicResponsiveListItemRenderer, ${twoRow.length} musicTwoRowItemRenderer');
      
      // Let's print section titles if any
      final sectionHeaders = findNodes(data, 'musicCarouselShelfBasicHeaderRenderer');
      for (final h in sectionHeaders) {
        final title = h['title']?['runs']?[0]?['text'];
        print('  Shelf: $title');
      }
    }
  }

  client.close();
}

