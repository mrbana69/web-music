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
  final query = 'Sfera Ebbasta';

  final uri = Uri.parse('https://music.youtube.com/youtubei/v1/search?prettyPrint=false');
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
    'query': query,
  });

  final headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
    'Origin': 'https://music.youtube.com',
  };

  final res = await client.post(uri, headers: headers, body: payload);
  print('Search status: ${res.statusCode}');
  final data = jsonDecode(res.body);

  // Let's see what shelves exist
  final shelves = findNodes(data, 'musicShelfRenderer');
  print('Found ${shelves.length} musicShelfRenderer');
  for (int i = 0; i < shelves.length; i++) {
    final s = shelves[i];
    final title = s['title']?['runs']?[0]?['text'] ?? 'No title';
    final contents = s['contents'] as List? ?? [];
    print('  Shelf $i: title="$title", contents=${contents.length}');
  }

  final cardShelves = findNodes(data, 'musicCardShelfRenderer');
  print('Found ${cardShelves.length} musicCardShelfRenderer');
  for (int i = 0; i < cardShelves.length; i++) {
    final s = cardShelves[i];
    final title = s['header']?['musicCardShelfHeaderBasicRenderer']?['title']?['runs']?[0]?['text'] ?? 'No title';
    final contents = s['contents'] as List? ?? [];
    print('  CardShelf $i: title="$title", contents=${contents.length}');
  }

  client.close();
}

