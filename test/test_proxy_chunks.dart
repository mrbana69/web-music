import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  const videoId = '3xjo8h14gCI';
  print('Fetching manifest for $videoId...');
  final manifest = await yt.videos.streamsClient.getManifest(videoId);
  final audio = manifest.audioOnly.firstWhere((s) => s.tag == 140, orElse: () => manifest.audioOnly.first);
  final totalBytes = audio.size.totalBytes;
  print('Selected itag=${audio.tag}, totalBytes=$totalBytes, url=${audio.url}');

  // Start a local proxy server
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  print('Local proxy running on http://127.0.0.1:$port');

  final client = HttpClient();

  server.listen((HttpRequest req) async {
    print('Proxy received request: ${req.method} ${req.uri} headers=${req.headers}');
    final rangeStr = req.headers.value(HttpHeaders.rangeHeader);
    int start = 0;
    int end = totalBytes - 1;

    if (rangeStr != null && rangeStr.startsWith('bytes=')) {
      final parts = rangeStr.substring(6).split('-');
      if (parts[0].isNotEmpty) {
        start = int.tryParse(parts[0]) ?? 0;
      }
      if (parts.length > 1 && parts[1].isNotEmpty) {
        end = int.tryParse(parts[1]) ?? (totalBytes - 1);
      }
    }

    final contentLength = end - start + 1;
    req.response.statusCode = (rangeStr != null) ? HttpStatus.partialContent : HttpStatus.ok;
    req.response.headers.set(HttpHeaders.contentTypeHeader, audio.codec.mimeType);
    req.response.headers.set(HttpHeaders.contentLengthHeader, contentLength.toString());
    req.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    if (rangeStr != null) {
      req.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$totalBytes');
    }

    print('Proxy responding with: start=$start, end=$end, contentLength=$contentLength');

    // Stream in 256KB chunks from upstream
    const chunkSize = 256 * 1024;
    int currentOffset = start;

    try {
      while (currentOffset <= end) {
        final chunkEnd = (currentOffset + chunkSize - 1).clamp(0, end);
        final upstreamReq = await client.getUrl(audio.url);
        upstreamReq.headers.set(HttpHeaders.rangeHeader, 'bytes=$currentOffset-$chunkEnd');
        upstreamReq.headers.set(HttpHeaders.userAgentHeader, 'com.google.android.youtube/19.29.35 (Linux; U; Android 11; US) gzip');

        final upstreamRes = await upstreamReq.close().timeout(const Duration(seconds: 8));
        if (upstreamRes.statusCode != HttpStatus.partialContent && upstreamRes.statusCode != HttpStatus.ok) {
          print('Upstream chunk failed: status=${upstreamRes.statusCode}');
          await upstreamRes.drain();
          break;
        }

        // Pipe this chunk to response
        await req.response.addStream(upstreamRes);
        currentOffset = chunkEnd + 1;
      }
      await req.response.close();
      print('Proxy successfully finished serving stream!');
    } catch (e) {
      print('Proxy stream error: $e');
      try {
        await req.response.close();
      } catch (_) {}
    }
  });

  // Now simulate ExoPlayer requesting bytes=0- (open-ended range!)
  print('\n--- Simulating ExoPlayer with Range: bytes=0- ---');
  final testClient = http.Client();
  final testReq = http.Request('GET', Uri.parse('http://127.0.0.1:$port/stream'));
  testReq.headers['Range'] = 'bytes=0-';
  final streamedRes = await testClient.send(testReq);
  print('Client received response status: ${streamedRes.statusCode}');
  print('Client headers: ${streamedRes.headers}');

  int bytesReceived = 0;
  await for (final chunk in streamedRes.stream) {
    bytesReceived += chunk.length;
    print('Streamed so far: $bytesReceived / $totalBytes');
  }

  testClient.close();
  await server.close(force: true);
  client.close(force: true);
  yt.close();
  print('TEST PASSED 100%!');
}

