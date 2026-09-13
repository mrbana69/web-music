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
  final payload = jsonEncode({
    'context': {
      'client': {
        'clientName': 'WEB_REMIX',
        'clientVersion': '1.20241101.01.00',
        'hl': 'it',
        'gl': 'IT',
      },
      'user': {},
    },
    'browseId': 'FEmusic_home',
  });

  final headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
    'Origin': 'https://music.youtube.com',
  };

  final res = await client.post(uri, headers: headers, body: payload);
  final data = jsonDecode(res.body);
  
  final carouselShelves = findNodes(data, 'musicCarouselShelfRenderer');
  final standardShelves = findNodes(data, 'musicShelfRenderer');
  final allShelves = [...carouselShelves, ...standardShelves];

  print('Found ${allShelves.length} total shelves:');
  for (int i = 0; i < allShelves.length; i++) {
    final s = allShelves[i];
    final title = s['header']?['musicCarouselShelfBasicHeaderRenderer']?['title']?['runs']?[0]?['text'] ??
                  s['header']?['musicShelfBasicHeaderRenderer']?['title']?['runs']?[0]?['text'] ?? 'Untitled';
    final contents = s['contents'] as List? ?? [];
    print('  Shelf $i: "$title" (${contents.length} items)');
  }

  client.close();
}

