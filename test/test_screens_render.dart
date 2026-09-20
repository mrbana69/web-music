import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:preluded_music/models/artist.dart';
import 'package:preluded_music/models/album.dart';
import 'package:preluded_music/models/track.dart';
import 'package:preluded_music/services/storage_service.dart';
import 'package:preluded_music/services/api_service.dart';
import 'package:preluded_music/services/audio_handler.dart';
import 'package:preluded_music/providers/player_state.dart';
import 'package:preluded_music/providers/library_state.dart';
import 'package:preluded_music/ui/screens/artist_screen.dart';
import 'package:preluded_music/ui/screens/album_screen.dart';
import 'package:preluded_music/ui/screens/full_player_screen.dart';

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

class FakeAudioHandler {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _RealHttpOverrides();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async {
      return Directory.systemTemp.path;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (call) async {
      return null;
    });
  });

  testWidgets('Test ArtistScreen renders on desktop and mobile', (tester) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final api = ApiService(storage);
      final library = LibraryState(storage);
      final audioHandler = PreludedAudioHandler(api, storage);
      final player = PlayerState(audioHandler, api);

      final testArtist = Artist(
        id: 'UC3cvw22UbTYbH63m_9a_tAQ',
        name: 'BLANCO',
        picture: 'https://via.placeholder.com/150',
        bio: 'Bio di test',
        topTracks: [
          Track(
            id: 'v1',
            videoId: 'v1',
            title: 'Track 1',
            artistName: 'BLANCO',
            coverUrl: 'https://via.placeholder.com/150',
            durationMs: 180000,
          ),
        ],
        albums: [
          Album(
            id: 'MPREb_1',
            title: 'Album 1',
            artistName: 'BLANCO',
            coverUrl: 'https://via.placeholder.com/150',
            year: '2023',
          ),
        ],
      );

      // Test Desktop (width 1200)
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<StorageService>.value(value: storage),
            Provider<ApiService>.value(value: api),
            ChangeNotifierProvider<LibraryState>.value(value: library),
            ChangeNotifierProvider<PlayerState>.value(value: player),
          ],
          child: MaterialApp(
            home: ArtistScreen(artist: testArtist),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('BLANCO'), findsWidgets);
      expect(find.text('Track 1'), findsOneWidget);
      print('Desktop ArtistScreen pumped successfully!');

      // Test Mobile (width 400)
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<StorageService>.value(value: storage),
            Provider<ApiService>.value(value: api),
            ChangeNotifierProvider<LibraryState>.value(value: library),
            ChangeNotifierProvider<PlayerState>.value(value: player),
          ],
          child: MaterialApp(
            home: ArtistScreen(artist: testArtist),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('BLANCO'), findsWidgets);
      print('Mobile ArtistScreen pumped successfully!');
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('Test AlbumScreen renders on desktop and mobile', (tester) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final api = ApiService(storage);
      final library = LibraryState(storage);
      final audioHandler = PreludedAudioHandler(api, storage);
      final player = PlayerState(audioHandler, api);

      final testAlbum = Album(
        id: 'MPREb_4iQ6FcKjmN7',
        title: 'Innamorato',
        artistName: 'BLANCO',
        coverUrl: 'https://via.placeholder.com/150',
        year: '2023',
        tracks: [
          Track(
            id: 'v1',
            videoId: 'v1',
            title: 'Anima Tormentata',
            artistName: 'BLANCO',
            coverUrl: 'https://via.placeholder.com/150',
            durationMs: 180000,
          ),
        ],
      );

      // Desktop
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<StorageService>.value(value: storage),
            Provider<ApiService>.value(value: api),
            ChangeNotifierProvider<LibraryState>.value(value: library),
            ChangeNotifierProvider<PlayerState>.value(value: player),
          ],
          child: MaterialApp(
            home: AlbumScreen(album: testAlbum),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Innamorato'), findsWidgets);
      expect(find.text('Anima Tormentata'), findsOneWidget);
      print('Desktop AlbumScreen pumped successfully!');

      // Mobile
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<StorageService>.value(value: storage),
            Provider<ApiService>.value(value: api),
            ChangeNotifierProvider<LibraryState>.value(value: library),
            ChangeNotifierProvider<PlayerState>.value(value: player),
          ],
          child: MaterialApp(
            home: AlbumScreen(album: testAlbum),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Innamorato'), findsWidgets);
      print('Mobile AlbumScreen pumped successfully!');
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('Test FullPlayerScreen renders side-by-side on desktop and column on mobile', (tester) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final api = ApiService(storage);
      final library = LibraryState(storage);
      final audioHandler = PreludedAudioHandler(api, storage);
      final player = PlayerState(audioHandler, api);

      final track = Track(
        id: 'test_t1',
        videoId: 'test_t1',
        title: 'Mi Fai Impazzire',
        artistName: 'BLANCO & Sfera Ebbasta',
        coverUrl: 'https://via.placeholder.com/300',
        durationMs: 220000,
      );
      player.playTrack(track);

      // Desktop (width 1100 -> Side-by-side layout)
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<StorageService>.value(value: storage),
            Provider<ApiService>.value(value: api),
            ChangeNotifierProvider<LibraryState>.value(value: library),
            ChangeNotifierProvider<PlayerState>.value(value: player),
          ],
          child: const MaterialApp(
            home: FullPlayerScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Mi Fai Impazzire'), findsWidgets);
      expect(find.text('BLANCO & Sfera Ebbasta'), findsWidgets);
      print('Desktop FullPlayerScreen side-by-side pumped successfully!');

      // Mobile (width 400 -> Vertical column layout)
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<StorageService>.value(value: storage),
            Provider<ApiService>.value(value: api),
            ChangeNotifierProvider<LibraryState>.value(value: library),
            ChangeNotifierProvider<PlayerState>.value(value: player),
          ],
          child: const MaterialApp(
            home: FullPlayerScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Mi Fai Impazzire'), findsWidgets);
      print('Mobile FullPlayerScreen column pumped successfully!');

      await tester.pumpWidget(const SizedBox());
    });
  });
}
