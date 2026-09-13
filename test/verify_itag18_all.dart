import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  final testVideos = [
    '3xjo8h14gCI', // goosebumps
    '5oRc6oqn4nA',
    'fJ9rUzIMcZQ', // Queen - Bohemian Rhapsody
    'kJQP7kiw5Fk', // Luis Fonsi - Despacito
    'JGwWNGJdvx8', // Ed Sheeran - Shape of You
    'YQHsXMglC9A', // Adele - Hello
  ];

  final client = HttpClient();

  for (final vId in testVideos) {
    try {
      print('\nTesting video: $vId');
      final manifest = await yt.videos.streamsClient.getManifest(vId);
      final itag18 = manifest.muxed.firstWhere((s) => s.tag == 18, orElse: () => manifest.muxed.first);
      print('  Found itag=${itag18.tag}, size=${itag18.size.totalBytes}');
      
      // Test downloading past 1.5MB
      final req = await client.getUrl(itag18.url);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=1500000-1800000');
      req.headers.set(HttpHeaders.userAgentHeader, 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip');
      final res = await req.close();
      print('  Range 1.5MB-1.8MB status: HTTP ${res.statusCode}');
      if (res.statusCode == 206) {
        print('  ✅ PASS: $vId works 100% past 1MB!');
      } else {
        print('  ❌ FAIL: HTTP ${res.statusCode}');
      }
      await res.drain();
    } catch (e) {
      print('  Error on $vId: $e');
    }
  }

  client.close();
  yt.close();
}

