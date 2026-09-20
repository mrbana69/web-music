import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  test('Inspect OLAK5uy browse response', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _RealHttpOverrides();
    final client = http.Client();

    final testIds = [
      'OLAK5uy_mN25rQx52fXg1z8y2LSm1zZtJ1U9p0c58',
      'VLOLAK5uy_mN25rQx52fXg1z8y2LSm1zZtJ1U9p0c58',
    ];

    for (final id in testIds) {
      final uri = Uri.parse('https://music.youtube.com/youtubei/v1/browse?prettyPrint=false');
      final payload = jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20250101.01.00',
            'hl': 'it',
            'gl': 'IT',
          },
        },
        'browseId': id,
      });

      final headers = {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://music.youtube.com/',
        'Origin': 'https://music.youtube.com',
        'X-YouTube-Client-Name': '67',
        'X-YouTube-Client-Version': '1.20250101.01.00',
      };

      final res = await client.post(uri, headers: headers, body: payload);
      print('\n--- Browse ID: $id (status: ${res.statusCode}) ---');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        print('Top keys: ${data.keys.toList()}');
        if (data.containsKey('contents')) {
          print('Contents keys: ${(data['contents'] as Map).keys.toList()}');
          final sectionList = data['contents']?['singleColumnBrowseResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer'];
          print('SectionList contents: ${sectionList?['contents']?.length}');
        }
        if (data.containsKey('header')) {
          print('Header: ${(data['header'] as Map).keys.toList()}');
        }
      } else {
        print('Error body: ${res.body.substring(0, 200)}');
      }
    }
  });
}
