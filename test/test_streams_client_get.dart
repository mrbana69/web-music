import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  const vId = '3xjo8h14gCI';
  print('Getting manifest for $vId...');
  final manifest = await yt.videos.streamsClient.getManifest(vId);
  final audio = manifest.audioOnly.firstWhere((s) => s.tag == 140, orElse: () => manifest.audioOnly.first);
  final totalBytes = audio.size.totalBytes;
  print('audio itag: ${audio.tag}, totalBytes: $totalBytes');

  print('Calling streamsClient.get(audio)...');
  int bytesRead = 0;
  try {
    final stream = yt.videos.streamsClient.get(audio);
    await for (final chunk in stream) {
      bytesRead += chunk.length;
      if (bytesRead % 500000 < chunk.length) {
        print('  Downloaded $bytesRead / $totalBytes bytes (${(bytesRead * 100 / totalBytes).toStringAsFixed(1)}%)');
      }
    }
    print('\n🎉🎉🎉 streamsClient.get COMPLETED: downloaded $bytesRead out of $totalBytes bytes! 🎉🎉🎉');
  } catch (e, st) {
    print('Failed at $bytesRead bytes: $e\n$st');
  }

  yt.close();
}

