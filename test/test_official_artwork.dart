import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:preluded_music/services/storage_service.dart';
import 'package:preluded_music/services/api_service.dart';
import 'package:preluded_music/models/track.dart';

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  group('Official Studio Artwork & Song Prioritization Tests', () {
    late StorageService storage;
    late ApiService api;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await StorageService.init();
      api = ApiService(storage);
    });

    test('ApiService.search prioritizes official audio tracks over YouTube video thumbnails', () async {
      final res = await api.search('BAND4BAND', filter: 'all', limit: 10);
      final tracks = (res['tracks'] as List<Track>?) ?? [];

      expect(tracks, isNotEmpty);
      final topTrack = tracks.first;

      // The top track must be the official release with square googleusercontent cover, not a video thumbnail
      expect(topTrack.title.toUpperCase(), contains('BAND4BAND'));
      expect(topTrack.coverUrl, contains('googleusercontent.com'));
      expect(topTrack.coverUrl, isNot(contains('i.ytimg.com')));
    });

    test('ApiService.resolveOfficialArtwork resolves studio square artwork for video tracks', () async {
      final videoTrack = Track(
        id: 'XDxS9DfwmTo',
        videoId: 'XDxS9DfwmTo',
        title: 'BAND4BAND (con Lil Baby)',
        artistName: 'Central Cee e Lil Baby',
        coverUrl: 'https://i.ytimg.com/vi/XDxS9DfwmTo/hqdefault.jpg',
        durationMs: 210000,
      );

      final result = await api.resolveOfficialArtwork(videoTrack);
      expect(result, isNotNull);
      expect(result!['coverUrl'], isNotNull);
      expect(result['coverUrl'], isNotEmpty);
      expect(result['coverUrl']!.startsWith('https://'), isTrue);
      // Must not be a video frame thumbnail
      expect(result['coverUrl']!, isNot(contains('i.ytimg.com')));
      // Should have resolved the album or studio collection
      expect(result['album'], isNotNull);
    });
  });
}

