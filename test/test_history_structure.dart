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
      'client': {'clientName': 'WEB_REMIX', 'clientVersion': '1.20241101.01.00', 'hl': 'it', 'gl': 'IT'},
      'user': {},
    },
    'browseId': 'FEmusic_history',
  });
  final headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    'Origin': 'https://music.youtube.com',
  };
  final res = await client.post(uri, headers: headers, body: payload);
  print('HTTP ${res.statusCode}');
  final data = jsonDecode(res.body);
  final responsive = findNodes(data, 'musicResponsiveListItemRenderer');
  final twoRow = findNodes(data, 'musicTwoRowItemRenderer');
  print('Found ${responsive.length} responsive items, ${twoRow.length} twoRow items');
  client.close();
}

