import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  const vId = '3xjo8h14gCI';

  print('Testing manifest with requireWatchPage: false and androidVr...');
  try {
    final manifest = await yt.videos.streamsClient.getManifest(
      vId,
      requireWatchPage: false,
      ytClients: [YoutubeApiClient.androidVr],
    );
    print('androidVr audios: ${manifest.audioOnly.length}');
    for (final a in manifest.audioOnly) {
      print('  itag=${a.tag}, size=${a.size.totalBytes}, bitrate=${a.bitrate}');
    }
    final audio = manifest.audioOnly.first;
    print('Testing chunk 1.2MB-1.5MB on androidVr stream...');
    final client = HttpClient();
    final req = await client.getUrl(audio.url);
    req.headers.set(HttpHeaders.rangeHeader, 'bytes=1200000-1500000');
    final res = await req.close();
    print('androidVr Range response: HTTP ${res.statusCode}');
    await res.drain();
    client.close();
  } catch (e) {
    print('androidVr failed: $e');
  }

  print('\nTesting manifest with requireWatchPage: false and tv...');
  try {
    final manifest = await yt.videos.streamsClient.getManifest(
      vId,
      requireWatchPage: false,
      ytClients: [YoutubeApiClient.tv],
    );
    print('tv audios: ${manifest.audioOnly.length}');
    for (final a in manifest.audioOnly) {
      print('  itag=${a.tag}, size=${a.size.totalBytes}, bitrate=${a.bitrate}');
    }
  } catch (e) {
    print('tv failed: $e');
  }

  yt.close();
}

