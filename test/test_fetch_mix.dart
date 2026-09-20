import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:preluded_music/models/track.dart';
import 'package:preluded_music/services/storage_service.dart';
import 'package:preluded_music/services/api_service.dart';

void main() {
  test('Test fetchMix for real tracks', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    final api = ApiService(storage);

    final track = Track(
      id: 'g38rXP1LbPo',
      videoId: 'g38rXP1LbPo',
      title: 'Mi Fai Impazzire',
      artistName: 'BLANCO',
      coverUrl: 'https://example.com/cover.jpg',
      durationMs: 220000,
    );

    final mix = await api.fetchMix(track);
    print('fetchMix returned ${mix.length} tracks');
    for (var i = 0; i < mix.length && i < 5; i++) {
      final t = mix[i];
      print('  [$i] "${t.title}" by ${t.artistName} (id=${t.id})');
    }
    expect(mix.isNotEmpty, isTrue);
  });
}

