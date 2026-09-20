import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:preluded_music/services/local_stream_proxy.dart';

void main() {
  test('Test LocalStreamProxy streaming full song and past 1MB', () async {
    final proxy = LocalStreamProxy();
    await proxy.start();
    print('Proxy started on port: ${proxy.port}');

    final testVideos = [
      'a5HS7oQkiXU', // Central Cee & Lil Baby - BAND4BAND (user song)
      '3xjo8h14gCI', // Travis Scott - goosebumps
      'fJ9rUzIMcZQ', // Queen - Bohemian Rhapsody (long 6 min track)
      '5oRc6oqn4nA', // Marracash & Guè - CASINI
    ];

    final client = HttpClient();

    for (final vId in testVideos) {
      print('\n=======================================');
      print('Testing video: $vId');
      final streamUrl = proxy.getStreamUrl(vId);

      // 1. Request bytes 0 to 2MB (past the 1MB cutoff)
      final req1 = await client.getUrl(Uri.parse(streamUrl));
      req1.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1800000');
      final res1 = await req1.close().timeout(const Duration(seconds: 15));
      expect(res1.statusCode, equals(206));

      int bytes1 = 0;
      await for (final chunk in res1) {
        bytes1 += chunk.length;
      }
      print('  First chunk (0-1.8MB): $bytes1 bytes received');
      expect(bytes1, equals(1800001));

      // 2. Request deep into the song (e.g. 1.8MB to 2.5MB)
      final req2 = await client.getUrl(Uri.parse(streamUrl));
      req2.headers.set(HttpHeaders.rangeHeader, 'bytes=1800001-2500000');
      final res2 = await req2.close().timeout(const Duration(seconds: 15));
      expect(res2.statusCode, equals(206));

      int bytes2 = 0;
      await for (final chunk in res2) {
        bytes2 += chunk.length;
      }
      print('  Second chunk (1.8MB-2.5MB): $bytes2 bytes received');
      expect(bytes2, equals(700000));
      print('  ✅ PASS: $vId streamed flawlessly past 1MB and in middle/end!');
    }

    client.close();
    await proxy.stop();
  });
}

