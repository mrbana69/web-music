import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  test('Audio stream resolution test', () async {
    final yt = YoutubeExplode();
    final videoId = '5oRc6oqn4nA';

    final manifest = await yt.videos.streamsClient.getManifest(videoId);
    final audios = manifest.audioOnly;
    expect(audios.isNotEmpty, true);

    final preferred = audios.firstWhere(
      (s) => s.tag == 251 || s.tag == 140,
      orElse: () => audios.withHighestBitrate(),
    );
    expect(preferred.url.toString().isNotEmpty, true);

    yt.close();
  });
}

