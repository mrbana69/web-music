import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  const vId = '3xjo8h14gCI';
  final manifest = await yt.videos.streamsClient.getManifest(vId);
  final audio = manifest.audioOnly.firstWhere((s) => s.tag == 140, orElse: () => manifest.audioOnly.first);

  final client = HttpClient();
  
  // Test chunk 1: 0-262143
  print('--- Chunk 1: 0-262143 ---');
  final req1 = await client.getUrl(audio.url);
  req1.headers.set(HttpHeaders.rangeHeader, 'bytes=0-262143');
  req1.headers.set(HttpHeaders.userAgentHeader, 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip');
  final res1 = await req1.close();
  print('Chunk 1 status: ${res1.statusCode}');
  await res1.drain();

  // Test chunk at 1048576: 1048576-1310719
  print('\n--- Chunk 5: 1048576-1310719 ---');
  final req5 = await client.getUrl(audio.url);
  req5.headers.set(HttpHeaders.rangeHeader, 'bytes=1048576-1310719');
  req5.headers.set(HttpHeaders.userAgentHeader, 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip');
  final res5 = await req5.close();
  print('Chunk 5 status: ${res5.statusCode}');
  print('Chunk 5 headers:');
  res5.headers.forEach((k, v) => print('  $k: $v'));
  
  final body5 = await res5.transform(SystemEncoding().decoder).join();
  print('Chunk 5 body: $body5');

  client.close();
  yt.close();
}

