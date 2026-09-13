import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  const videoId = '3xjo8h14gCI';

  // Let's inspect manifest
  final manifest = await yt.videos.streamsClient.getManifest(videoId);
  print('audioOnly count: ${manifest.audioOnly.length}');
  for (final a in manifest.audioOnly) {
    print('  tag=${a.tag}, codec=${a.audioCodec}, container=${a.container.name}, bitrate=${a.bitrate}, size=${a.size.totalBytes}, fragments=${a.fragments.length}');
  }

  print('\nmuxed count: ${manifest.muxed.length}');
  for (final m in manifest.muxed) {
    print('  tag=${m.tag}, container=${m.container.name}, size=${m.size.totalBytes}');
  }

  print('\nhls count: ${manifest.hls.length}');
  for (final h in manifest.hls) {
    print('  tag=${h.tag}, container=${h.container.name}');
  }

  yt.close();
}

