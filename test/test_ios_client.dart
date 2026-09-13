import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  const videoId = '3xjo8h14gCI';
  print('Fetching manifest for $videoId with YoutubeApiClient.ios...');
  
  try {
    final manifest = await yt.videos.streamsClient.getManifest(
      videoId,
      ytClients: [YoutubeApiClient.ios],
    );
    
    print('Available audio streams: ${manifest.audioOnly.length}');
    for (final s in manifest.audioOnly) {
      print('  itag=${s.tag}, bitrate=${s.bitrate}, size=${s.size.totalBytes}, codec=${s.audioCodec}');
    }

    final audio = manifest.audioOnly.firstWhere(
      (s) => s.tag == 140,
      orElse: () => manifest.audioOnly.first,
    );
    final totalBytes = audio.size.totalBytes;
    print('\nTesting stream: itag=${audio.tag}, totalBytes=$totalBytes');
    print('Stream URL: ${audio.url}');

    // Test downloading chunks past 1MB (e.g. up to 2.5MB)
    final client = HttpClient();
    const chunkSize = 256 * 1024;
    int currentOffset = 0;
    final end = totalBytes - 1;
    int downloaded = 0;

    print('\nStarting chunk test past 1MB limit...');
    while (currentOffset < end && downloaded < 2500000) {
      final chunkEnd = (currentOffset + chunkSize - 1).clamp(0, end);
      final req = await client.getUrl(audio.url);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=$currentOffset-$chunkEnd');
      req.headers.set(HttpHeaders.userAgentHeader, 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)');

      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 206 && res.statusCode != 200) {
        print('CHUNK FAILED at offset $currentOffset-$chunkEnd: HTTP ${res.statusCode}');
        await res.drain();
        break;
      }

      int chunkBytes = 0;
      await for (final data in res) {
        chunkBytes += data.length;
      }
      downloaded += chunkBytes;
      print('Downloaded chunk $currentOffset-$chunkEnd ($chunkBytes bytes). Total downloaded: $downloaded / $totalBytes');
      currentOffset = chunkEnd + 1;
    }

    client.close();
    if (downloaded >= 2000000) {
      print('\n🎉 SUCCESS! Downloaded $downloaded bytes without 403 error using IOS client!');
    }
  } catch (e, st) {
    print('Error: $e\n$st');
  } finally {
    yt.close();
  }
}

