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

  void printKeys(dynamic node, String prefix, int depth) {
    if (depth > 5) return;
    if (node is Map) {
      for (final k in node.keys) {
        print('$prefix$k');
        if (node[k] is Map || node[k] is List) {
          printKeys(node[k], '$prefix  ', depth + 1);
        }
      }
    } else if (node is List) {
      print('$prefix[List of ${node.length}]');
      if (node.isNotEmpty) {
        printKeys(node[0], '$prefix  ', depth + 1);
      }
    }
  }

  printKeys(data['contents'], '', 0);

  client.close();
}

