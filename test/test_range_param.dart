import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  const vId = '3xjo8h14gCI';
  print('Fetching manifest...');
  final manifest = await yt.videos.streamsClient.getManifest(vId);
  final audio = manifest.audioOnly.firstWhere((s) => s.tag == 140, orElse: () => manifest.audioOnly.first);
  final totalBytes = audio.size.totalBytes;
  print('Total bytes: $totalBytes');

  // Append &range=0-$totalBytes to the URL
  final rawUrl = audio.url.toString();
  final fixedUrl = Uri.parse('$rawUrl&range=0-$totalBytes');
  print('Fixed URL with &range param: $fixedUrl');

  final client = HttpClient();

  // Test 1: Download chunks using Range header on fixedUrl past 1MB
  print('\n--- TEST 1: Chunk 1.2MB-1.5MB on fixedUrl ---');
  final req1 = await client.getUrl(fixedUrl);
  req1.headers.set(HttpHeaders.rangeHeader, 'bytes=1200000-1500000');
  req1.headers.set(HttpHeaders.userAgentHeader, 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip');
  final res1 = await req1.close();
  print('Test 1 Status: ${res1.statusCode}');
  await res1.drain();

  // Test 2: Download stream from 0 onwards continuously past 2MB
  print('\n--- TEST 2: Stream continuously on fixedUrl ---');
  final req2 = await client.getUrl(fixedUrl);
  req2.headers.set(HttpHeaders.userAgentHeader, 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip');
  final res2 = await req2.close();
  print('Test 2 Status: ${res2.statusCode}');
  int received = 0;
  try {
    await for (final chunk in res2) {
      received += chunk.length;
      if (received >= 2500000) {
        print('  Received $received / $totalBytes bytes (${(received * 100 / totalBytes).toStringAsFixed(1)}%)');
        break;
      }
    }
    if (received >= 2000000) {
      print('🎉🎉🎉 HOLY MOLY! STREAMED $received BYTES PAST 1MB WITH ZERO 403 ERROR! 🎉🎉🎉');
    }
  } catch (e) {
    print('Test 2 error: $e');
  }

  client.close();
  yt.close();
}

