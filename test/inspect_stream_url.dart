import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  const vId = '3xjo8h14gCI';
  final manifest = await yt.videos.streamsClient.getManifest(vId);
  for (final s in manifest.audioOnly) {
    print('itag: ${s.tag}, bitrate: ${s.bitrate}');
    print('URL: ${s.url}\n');
  }
  yt.close();
}

