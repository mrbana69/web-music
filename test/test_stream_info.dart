import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  final manifest = await yt.videos.streamsClient.getManifest('3xjo8h14gCI');
  final muxed18 = manifest.muxed.firstWhere((s) => s.tag == 18, orElse: () => manifest.muxed.first);
  
  final StreamInfo s = muxed18;
  print('tag: ${s.tag}');
  print('url: ${s.url}');
  print('size: ${s.size.totalBytes}');
  print('codec: ${s.codec.mimeType}');
  print('bitrate: ${s.bitrate.bitsPerSecond}');

  yt.close();
}

