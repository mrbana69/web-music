import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  const vId = '3xjo8h14gCI';
  print('Fetching manifest...');
  final manifest = await yt.videos.streamsClient.getManifest(vId);
  final muxed18 = manifest.muxed.firstWhere((s) => s.tag == 18);
  print('itag 18 size: ${muxed18.size.totalBytes}');
  print('itag 18 url: ${muxed18.url}');

  final client = HttpClient();
  // Test chunk 1.2MB - 1.5MB
  final req = await client.getUrl(muxed18.url);
  req.headers.set(HttpHeaders.rangeHeader, 'bytes=1200000-1500000');
  req.headers.set(HttpHeaders.userAgentHeader, 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip');
  final res = await req.close();
  print('itag 18 Range 1.2MB-1.5MB: HTTP ${res.statusCode}');
  await res.drain();

  // Test continuous streaming
  print('Testing continuous stream from 0...');
  final req2 = await client.getUrl(muxed18.url);
  req2.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
  req2.headers.set(HttpHeaders.userAgentHeader, 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip');
  final res2 = await req2.close();
  print('Stream status: ${res2.statusCode}');
  int received = 0;
  try {
    await for (final chunk in res2) {
      received += chunk.length;
      if (received >= 2500000) {
        print('Streamed $received bytes!');
        break;
      }
    }
    if (received >= 2000000) {
      print('🎉🎉🎉 ITAG 18 STREAMS PAST 1MB WITH ZERO 403! 🎉🎉🎉');
    }
  } catch (e) {
    print('Error: $e');
  }

  client.close();
  yt.close();
}

