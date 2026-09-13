import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(Uri.parse('https://api.invidious.io/instances.json?sort_by=type,health'));
  final list = jsonDecode(res.body) as List;
  print('Total instances: ${list.length}');
  
  const vId = '3xjo8h14gCI';

  for (final item in list) {
    final domain = item[0] as String;
    final info = item[1] as Map;
    final type = info['type']?.toString();
    final uri = info['uri']?.toString();
    if (type != 'https' || uri == null) continue;

    print('Checking $uri...');
    try {
      final videoRes = await http.get(
        Uri.parse('$uri/api/v1/videos/$vId?fields=adaptiveFormats'),
      ).timeout(const Duration(seconds: 4));

      if (videoRes.statusCode == 200) {
        final vData = jsonDecode(videoRes.body);
        final formats = vData['adaptiveFormats'] as List? ?? [];
        final audio = formats.firstWhere((f) => (f['type']?.toString() ?? '').contains('audio'), orElse: () => null);
        if (audio != null) {
          final url = audio['url'] as String;
          print('  Found audio stream url on $uri!');
          // Test downloading chunk past 1MB (1.5MB - 1.8MB)
          final req = await HttpClient().getUrl(Uri.parse(url));
          req.headers.set(HttpHeaders.rangeHeader, 'bytes=1500000-1800000');
          final testRes = await req.close().timeout(const Duration(seconds: 4));
          print('  Range test: HTTP ${testRes.statusCode}');
          if (testRes.statusCode == 206) {
            print('  🎉🎉🎉 WORKING INSTANCE FOUND: $uri -> $url 🎉🎉🎉');
            await testRes.drain();
            break;
          }
          await testRes.drain();
        }
      }
    } catch (_) {}
  }
}

