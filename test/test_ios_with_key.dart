import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  const vId = '3xjo8h14gCI';
  final client = http.Client();

  final payload = {
    'context': {
      'client': {
        'clientName': 'IOS',
        'clientVersion': '20.10.4',
        'deviceMake': 'Apple',
        'deviceModel': 'iPhone16,2',
        'userAgent': 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
        'hl': 'en',
        'platform': 'MOBILE',
        'osName': 'IOS',
        'osVersion': '18.1.0.22B83',
        'timeZone': 'UTC',
        'gl': 'US',
        'utcOffsetMinutes': 0
      }
    },
    'videoId': vId,
  };

  final uri = Uri.parse('https://www.youtube.com/youtubei/v1/player?key=AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc&prettyPrint=false');
  final res = await client.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
      'X-YouTube-Client-Name': '5',
      'X-YouTube-Client-Version': '20.10.4',
    },
    body: jsonEncode(payload),
  );

  print('Status: ${res.statusCode}');
  final data = jsonDecode(res.body);
  print('playabilityStatus: ${data['playabilityStatus']?['status']}');
  final streamingData = data['streamingData'];
  print('streamingData present: ${streamingData != null}');

  if (streamingData != null) {
    final formats = streamingData['adaptiveFormats'] as List? ?? [];
    print('Adaptive formats count: ${formats.length}');
    for (final f in formats) {
      final mime = f['mimeType']?.toString() ?? '';
      if (mime.startsWith('audio/')) {
        print('Audio format: itag=${f['itag']}, mime=$mime, bitrate=${f['bitrate']}, url=${f['url'] != null ? "DIRECT_URL" : "CIPHER"}');
        if (f['url'] != null) {
          final streamUrl = f['url'] as String;
          print('Testing download of chunk 1.2MB-1.5MB from IOS direct URL...');
          final httpRaw = HttpClient();
          final req = await httpRaw.getUrl(Uri.parse(streamUrl));
          req.headers.set(HttpHeaders.rangeHeader, 'bytes=1200000-1500000');
          req.headers.set(HttpHeaders.userAgentHeader, 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)');
          final testRes = await req.close();
          print('Chunk 1.2MB-1.5MB response: HTTP ${testRes.statusCode}');
          if (testRes.statusCode == 206) {
            print('🎉🎉🎉 SUCCESS! IOS CLIENT DIRECT STREAM CAN DOWNLOAD PAST 1MB! (Status 206) 🎉🎉🎉');
          } else {
            print('Failed with ${testRes.statusCode}');
          }
          await testRes.drain();
          httpRaw.close();
        }
      }
    }
  }

  client.close();
}

