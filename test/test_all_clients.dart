import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  const vId = '3xjo8h14gCI';
  final client = http.Client();

  final testConfigs = [
    {
      'name': 'ANDROID_VR',
      'url': 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
      'payload': {
        'context': {
          'client': {
            'clientName': 'ANDROID_VR',
            'clientVersion': '1.56.21',
            'deviceModel': 'Quest 3',
            'osVersion': '12',
            'osName': 'Android',
            'androidSdkVersion': '32',
            'hl': 'en',
            'gl': 'US',
          }
        },
        'videoId': vId,
      }
    },
    {
      'name': 'ANDROID_TESTSUITE',
      'url': 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
      'payload': {
        'context': {
          'client': {
            'clientName': 'ANDROID_TESTSUITE',
            'clientVersion': '1.9',
            'hl': 'en',
            'gl': 'US',
          }
        },
        'videoId': vId,
      }
    },
    {
      'name': 'TVHTML5',
      'url': 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
      'payload': {
        'context': {
          'client': {
            'clientName': 'TVHTML5',
            'clientVersion': '7.20240724.13.00',
            'hl': 'en',
            'gl': 'US',
          }
        },
        'videoId': vId,
      }
    },
    {
      'name': 'WEB_REMIX',
      'url': 'https://music.youtube.com/youtubei/v1/player?prettyPrint=false',
      'payload': {
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20241101.01.00',
            'hl': 'it',
            'gl': 'IT',
          }
        },
        'videoId': vId,
      }
    },
    {
      'name': 'IOS',
      'url': 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
      'payload': {
        'context': {
          'client': {
            'clientName': 'IOS',
            'clientVersion': '19.45.4',
            'deviceModel': 'iPhone16,2',
            'userAgent': 'com.google.ios.youtube/19.45.4 (iPhone16,2; U; CPU iOS 18_1 like Mac OS X; en_US)',
            'hl': 'en',
            'gl': 'US',
          }
        },
        'videoId': vId,
      }
    }
  ];

  for (final config in testConfigs) {
    final name = config['name'] as String;
    print('\n==================== Testing $name ====================');
    try {
      final res = await client.post(
        Uri.parse(config['url'] as String),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        },
        body: jsonEncode(config['payload']),
      ).timeout(const Duration(seconds: 8));

      print('$name player status: ${res.statusCode}');
      if (res.statusCode != 200) {
        print('$name returned ${res.statusCode}: ${res.body.substring(0, res.body.length.clamp(0, 100))}');
        continue;
      }

      final data = jsonDecode(res.body);
      final playability = data['playabilityStatus'];
      print('$name playability: ${playability?['status']}');

      final streamingData = data['streamingData'];
      if (streamingData == null) {
        print('$name streamingData is NULL');
        continue;
      }

      final adaptive = streamingData['adaptiveFormats'] as List? ?? [];
      final audioFormats = adaptive.where((f) => (f['mimeType']?.toString() ?? '').startsWith('audio/')).toList();
      print('$name audioFormats found: ${audioFormats.length}');

      String? streamUrl;
      int? itag;
      int? contentLength;
      for (final f in audioFormats) {
        if (f['url'] != null) {
          streamUrl = f['url'];
          itag = f['itag'];
          contentLength = int.tryParse(f['contentLength']?.toString() ?? '');
          print('  Found format with direct URL! itag=$itag, mimeType=${f['mimeType']}, bitrate=${f['bitrate']}, contentLength=$contentLength');
          break;
        } else if (f['signatureCipher'] != null || f['cipher'] != null) {
          print('  Format has cipher (needs deciphering)');
        }
      }

      if (streamUrl != null) {
        print('\nTesting chunk streaming past 1MB on $name (url=${streamUrl.substring(0, 80)}...)...');
        final httpRaw = HttpClient();
        
        // Test chunk past 1MB: 1,200,000 to 1,400,000
        final req = await httpRaw.getUrl(Uri.parse(streamUrl));
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=1200000-1400000');
        final testRes = await req.close();
        print('  Range 1200000-1400000 response: HTTP ${testRes.statusCode}');
        if (testRes.statusCode == 206) {
          print('  🎉 $name WORKS PAST 1MB! (Status 206)');
        } else {
          print('  ❌ $name failed with ${testRes.statusCode}');
        }
        await testRes.drain();
        httpRaw.close();
      }
    } catch (e) {
      print('$name error: $e');
    }
  }

  client.close();
}

