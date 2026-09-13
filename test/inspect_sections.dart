import 'dart:convert';
import 'package:http/http.dart' as http;

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
  final data = jsonDecode(res.body);
  final sectionList = data['contents']['tabbedSearchResultsRenderer']['tabs'][0]['tabRenderer']['content']['sectionListRenderer']['contents'] as List;

  print('sectionList has ${sectionList.length} sections:');
  for (int i = 0; i < sectionList.length; i++) {
    final sec = sectionList[i] as Map;
    print('Section $i keys: ${sec.keys.toList()}');
    for (final k in sec.keys) {
      if (sec[k] is Map) {
        final inner = sec[k] as Map;
        print('  $k keys: ${inner.keys.toList()}');
        if (inner.containsKey('header')) {
          print('    header: ${inner['header']}');
        }
        if (inner.containsKey('title')) {
          print('    title: ${inner['title']}');
        }
        if (inner.containsKey('contents')) {
          print('    contents length: ${(inner['contents'] as List).length}');
        }
        if (inner.containsKey('items')) {
          print('    items length: ${(inner['items'] as List).length}');
        }
      }
    }
  }

  client.close();
}

