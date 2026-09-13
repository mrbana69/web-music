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
  final data = jsonDecode(res.body);
  
  final responsiveItems = findNodes(data, 'musicResponsiveListItemRenderer');
  for (int i = 0; i < responsiveItems.length; i++) {
    final item = responsiveItems[i];
    final flexCols = item['flexColumns'] as List? ?? [];
    final col0 = flexCols.isNotEmpty ? (flexCols[0] as Map)['musicResponsiveListItemFlexColumnRenderer'] : null;
    final title = col0?['text']?['runs']?[0]?['text'];
    final col1 = flexCols.length > 1 ? (flexCols[1] as Map)['musicResponsiveListItemFlexColumnRenderer'] : null;
    final subtitle = ((col1?['text']?['runs'] as List?) ?? []).map((r) => r['text']).join('');
    final ep = col0?['text']?['runs']?[0]?['navigationEndpoint'];
    final pageType = ep?['browseEndpoint']?['browseEndpointContextSupportedConfigs']?['browseEndpointContextMusicConfig']?['pageType'] ??
                     ep?['watchEndpoint']?['watchEndpointMusicSupportedConfigs']?['watchEndpointMusicConfig']?['musicVideoType'] ?? 'Unknown';
    print('$i: "$title" | "$subtitle" | type=$pageType');
  }

  client.close();
}

