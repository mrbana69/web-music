import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:preluded_music/models/track.dart';
import 'package:preluded_music/models/album.dart';
import 'package:preluded_music/models/artist.dart';
import 'package:preluded_music/models/playlist.dart';
import 'package:preluded_music/providers/player_state.dart';
import 'package:preluded_music/providers/library_state.dart';
import 'package:preluded_music/services/storage_service.dart';
import 'package:preluded_music/services/api_service.dart';
import 'package:preluded_music/services/audio_handler.dart';
import 'package:preluded_music/ui/widgets/stitch_track_row.dart';
import 'package:preluded_music/ui/screens/artist_screen.dart';
import 'package:preluded_music/ui/theme/app_theme.dart';

class _FakeJustAudioPlatform extends JustAudioPlatform {
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    return _FakeAudioPlayerPlatform(request.id);
  }
  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async {
    return DisposePlayerResponse();
  }
  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(DisposeAllPlayersRequest request) async {
    return DisposeAllPlayersResponse();
  }
}

class _FakeAudioPlayerPlatform extends AudioPlayerPlatform {
  _FakeAudioPlayerPlatform(super.id);
  final _eventController = StreamController<PlaybackEventMessage>.broadcast();
  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _eventController.stream;
  @override
  Future<LoadResponse> load(LoadRequest request) async => LoadResponse(duration: const Duration(seconds: 180));
  @override
  Future<PlayResponse> play(PlayRequest request) async => PlayResponse();
  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();
  @override
  Future<SeekResponse> seek(SeekRequest request) async => SeekResponse();
  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async => SetVolumeResponse();
  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async => SetSpeedResponse();
  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async => SetLoopModeResponse();
  @override
  Future<SetShuffleModeResponse> setShuffleMode(SetShuffleModeRequest request) async => SetShuffleModeResponse();
}

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    AppTheme.isTesting = true;
    GoogleFonts.config.allowRuntimeFetching = false;
    HttpOverrides.global = _RealHttpOverrides();
    JustAudioPlatform.instance = _FakeJustAudioPlatform();
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (methodCall) async => '.');
  });

  group('Discography and Like Button Tests', () {
    testWidgets('StitchTrackRow renders Heart/Like button and toggles like state', (tester) async {
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        final storage = await StorageService.init();
        final api = ApiService(storage);
        final library = LibraryState(storage);
        final audioHandler = PreludedAudioHandler(api, storage);
        final player = PlayerState(audioHandler, api);

        final testTrack = Track(
          id: 't_like_1',
          videoId: 'v_like_1',
          title: 'Canzone Test',
          artistName: 'Artista Test',
          albumName: 'Album Test',
          coverUrl: '',
          durationMs: 180000,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PlayerState>.value(value: player),
              ChangeNotifierProvider<LibraryState>.value(value: library),
              Provider<ApiService>.value(value: api),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: StitchTrackRow(
                  track: testTrack,
                  queue: [testTrack],
                  index: 0,
                ),
              ),
            ),
          ),
        );

        // Verify Heart button is present (border icon initially)
        expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
        expect(find.byIcon(Icons.lyrics_rounded), findsNothing);
        expect(library.isLiked(testTrack.id), isFalse);

        // Tap Heart button to Like
        await tester.tap(find.byIcon(Icons.favorite_border_rounded));
        await tester.pumpAndSettle();

        // Verify now liked
        expect(library.isLiked(testTrack.id), isTrue);
        expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);

        // Tap Heart again to Unlike
        await tester.tap(find.byIcon(Icons.favorite_rounded));
        await tester.pumpAndSettle();

        expect(library.isLiked(testTrack.id), isFalse);
        expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      });
    });

    testWidgets('ArtistScreen discography distinguishes Albums, Singles, and Playlists with correct badges', (tester) async {
      await tester.runAsync(() async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        SharedPreferences.setMockInitialValues({});
        final storage = await StorageService.init();
        final api = ApiService(storage);
        final library = LibraryState(storage);
        final audioHandler = PreludedAudioHandler(api, storage);
        final player = PlayerState(audioHandler, api);

        final dummyArtist = Artist(
          id: 'UC_test_artist',
          name: 'Superstar Artist',
          picture: '',
          bio: 'Bio di prova',
          topTracks: [
            Track(
              id: 'pop_1',
              videoId: 'pop_1',
              title: 'Hit Popolare',
              artistName: 'Superstar Artist',
              albumName: 'Grande Album',
              coverUrl: '',
              durationMs: 200000,
            ),
          ],
          albums: [
            Album(
              id: 'alb_1',
              title: 'Grande Album',
              artistName: 'Superstar Artist',
              coverUrl: '',
              year: '2023',
              type: 'Album',
            ),
          ],
          singles: [
            Album(
              id: 'sng_1',
              title: 'Singolo Estivo',
              artistName: 'Superstar Artist',
              coverUrl: '',
              year: '2024',
              type: 'Single',
            ),
          ],
          playlists: [
            Playlist(
              id: 'pl_1',
              title: 'Questa e Superstar',
              subtitle: 'Playlist • Preluded',
              coverUrl: '',
              tracks: [],
              isLocal: false,
            ),
          ],
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PlayerState>.value(value: player),
              ChangeNotifierProvider<LibraryState>.value(value: library),
              Provider<ApiService>.value(value: api),
            ],
            child: MaterialApp(
              home: ArtistScreen(artist: dummyArtist),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Check that discography badges are distinct and accurate
        expect(find.text('ALBUM'), findsWidgets);
        expect(find.text('SINGOLO'), findsWidgets);
        expect(find.text('PLAYLIST'), findsWidgets);

        // Verify that full album has 'Album • 2023' and single has 'Singolo • 2024'
        expect(find.text('Album • 2023'), findsWidgets);
        expect(find.text('Singolo • 2024'), findsWidgets);
        expect(find.text('Playlist • Preluded'), findsWidgets);

        // Verify filter chips
        expect(find.text('Tutto'), findsWidgets);
        expect(find.textContaining('Album'), findsWidgets);
        expect(find.textContaining('Singoli'), findsWidgets);
        expect(find.textContaining('Playlist'), findsWidgets);
      });
    });
  });
}

