import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  const vId = '3xjo8h14gCI';
  final client = http.Client();

  final endpoints = [
    'https://inv.tux.pizza',
    'https://invidious.nerdvpn.de',
    'https://yewtu.be',
    'https://invidious.private.coffee',
    'https://inv.nadeko.net',
    'https://invidious.jing.rocks',
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.drgns.space',
    'https://api.piped.privacydev.net',
    'https://pipedapi-libre.kavin.rocks',
    'https://piped.video',
  ];

  for (final ep in endpoints) {
    try {
      print('\nTesting endpoint: $ep');
      String? streamUrl;
      if (ep.contains('piped')) {
        final res = await client.get(Uri.parse('$ep/streams/$vId')).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final audioList = data['audioStreams'] as List? ?? [];
          if (audioList.isNotEmpty) {
            streamUrl = audioList.first['url'];
          }
        }
      } else {
        final res = await client.get(Uri.parse('$ep/api/v1/videos/$vId?fields=adaptiveFormats')).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final formats = data['adaptiveFormats'] as List? ?? [];
          final audio = formats.firstWhere((f) => (f['type']?.toString() ?? '').contains('audio'), orElse: () => null);
          if (audio != null) {
            streamUrl = audio['url'];
          }
        }
      }

      if (streamUrl != null) {
        print('  Found streamUrl: ${streamUrl.substring(0, 60)}...');
        final rawClient = HttpClient();
        final req = await rawClient.getUrl(Uri.parse(streamUrl));
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=1500000-1800000');
        final testRes = await req.close();
        print('  Range 1.5MB-1.8MB: HTTP ${testRes.statusCode}');
        if (testRes.statusCode == 206 || testRes.statusCode == 200) {
          print('  🎉🎉🎉 BINGO! $ep WORKS FOR STREAMING PAST 1MB! 🎉🎉🎉');
          await testRes.drain();
          rawClient.close();
          break;
        }
        await testRes.drain();
        rawClient.close();
      }
    } catch (e) {
      print('  Failed: $e');
    }
  }

  client.close();
}

