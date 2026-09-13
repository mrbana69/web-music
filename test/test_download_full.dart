import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  const vId = '3xjo8h14gCI';
  print('Fetching manifest for $vId...');
  final manifest = await yt.videos.streamsClient.getManifest(vId);
  final audio = manifest.audioOnly.firstWhere((s) => s.tag == 140, orElse: () => manifest.audioOnly.first);
  final totalBytes = audio.size.totalBytes;
  print('audio url: ${audio.url}');
  print('totalBytes: $totalBytes');

  // Test 1: Single continuous GET stream without Range chunks
  print('\n--- TEST 1: Single continuous GET (like standard media player) ---');
  final client = HttpClient();
  final req = await client.getUrl(audio.url);
  req.headers.set(HttpHeaders.userAgentHeader, 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip');
  
  final res = await req.close();
  print('Test 1 Status: ${res.statusCode}');
  print('Test 1 Headers:');
  res.headers.forEach((name, values) => print('  $name: $values'));

  int received1 = 0;
  try {
    await for (final chunk in res) {
      received1 += chunk.length;
      if (received1 % 500000 < chunk.length) {
        print('  Received $received1 / $totalBytes bytes (${(received1 * 100 / totalBytes).toStringAsFixed(1)}%)');
      }
    }
    print('Test 1 COMPLETED: received $received1 bytes out of $totalBytes!');
  } catch (e) {
    print('Test 1 FAILED at $received1 bytes: $e');
  }

  // Test 2: Range request starting at 1.5MB: bytes=1500000-
  print('\n--- TEST 2: Range request starting at 1.5MB (bytes=1500000-) ---');
  final req2 = await client.getUrl(audio.url);
  req2.headers.set(HttpHeaders.rangeHeader, 'bytes=1500000-');
  req2.headers.set(HttpHeaders.userAgentHeader, 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip');
  final res2 = await req2.close();
  print('Test 2 Status: ${res2.statusCode}');
  int received2 = 0;
  try {
    await for (final chunk in res2) {
      received2 += chunk.length;
      if (received2 % 500000 < chunk.length) {
        print('  Received $received2 bytes');
      }
    }
    print('Test 2 COMPLETED: received $received2 bytes!');
  } catch (e) {
    print('Test 2 FAILED at $received2 bytes: $e');
  }

  client.close();
  yt.close();
}

