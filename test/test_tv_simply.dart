import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  const vId = '3xjo8h14gCI';
  final client = http.Client();

  final payload = {
    'context': {
      'client': {
        'clientName': 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
        'clientVersion': '2.0',
        'hl': 'en',
        'gl': 'US',
        'utcOffsetMinutes': 0,
      },
      'thirdParty': {'embedUrl': 'https://www.youtube.com/watch?v=$vId'},
    },
    'videoId': vId,
    'contentCheckOk': true,
    'racyCheckOk': true,
  };

  final res = await client.post(
    Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false'),
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Origin': 'https://www.youtube.com',
      'Referer': 'https://www.youtube.com/',
    },
    body: jsonEncode(payload),
  );

  print('TVHTML5_SIMPLY_EMBEDDED_PLAYER status: ${res.statusCode}');
  final data = jsonDecode(res.body);
  print('playability: ${data['playabilityStatus']?['status']}');
  final streamingData = data['streamingData'];
  print('streamingData: ${streamingData != null}');
  if (streamingData != null) {
    final formats = (streamingData['adaptiveFormats'] as List? ?? [])..addAll(streamingData['formats'] as List? ?? []);
    print('formats count: ${formats.length}');
    for (final f in formats) {
      if ((f['mimeType']?.toString() ?? '').startsWith('audio/')) {
        print('audio format: itag=${f['itag']}, url=${f['url'] != null ? "DIRECT" : "CIPHER"}');
      }
    }
  }

  client.close();
}

