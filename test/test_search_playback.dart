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
import 'package:preluded_music/services/storage_service.dart';
import 'package:preluded_music/services/api_service.dart';
import 'package:preluded_music/services/audio_handler.dart';
import 'package:preluded_music/providers/player_state.dart';
import 'package:preluded_music/providers/library_state.dart';
import 'package:preluded_music/ui/widgets/track_tile.dart';
import 'package:preluded_music/ui/theme/app_theme.dart';

const List<int> _transparentPng = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout = const Duration(seconds: 8);
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();
  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _transparentPng.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream<List<int>>.fromIterable([_transparentPng]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

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
  Future<LoadResponse> load(LoadRequest request) async {
    return LoadResponse(duration: const Duration(seconds: 180));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    return SeekResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async {
    return SetVolumeResponse();
  }

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async {
    return SetSpeedResponse();
  }

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    return SetLoopModeResponse();
  }

  @override
  Future<SetShuffleModeResponse> setShuffleMode(SetShuffleModeRequest request) async {
    return SetShuffleModeResponse();
  }

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async {
    return SetPitchResponse();
  }

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
      SetAndroidAudioAttributesRequest request) async {
    return SetAndroidAudioAttributesResponse();
  }

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    await _eventController.close();
    return DisposeResponse();
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    AppTheme.isTesting = true;
    GoogleFonts.config.allowRuntimeFetching = false;
    HttpOverrides.global = _MockHttpOverrides();
    JustAudioPlatform.instance = _FakeJustAudioPlatform();
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (methodCall) async {
      return '.';
    });
  });

  testWidgets('TrackTile tap initiates playback and sets playing to true', (tester) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final api = ApiService(storage);
      final libraryState = LibraryState(storage);
      final audioHandler = PreludedAudioHandler(api, storage);
      final playerState = PlayerState(audioHandler, api);

      final testTrack = Track(
        id: 'song_123',
        videoId: 'song_123',
        title: 'Canzone Test',
        artistName: 'Artista Test',
        coverUrl: 'https://via.placeholder.com/150',
        durationMs: 180000,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: playerState),
            ChangeNotifierProvider.value(value: libraryState),
            Provider.value(value: api),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TrackTile(
                track: testTrack,
                queue: [testTrack],
                index: 0,
              ),
            ),
          ),
        ),
      );

      // Initial state: not playing, no current track
      expect(playerState.currentTrack, isNull);
      expect(playerState.isPlaying, isFalse);

      // Tap the TrackTile
      await tester.tap(find.byType(TrackTile));
      await tester.pump();

      // After tap: currentTrack is set and isPlaying is immediately true!
      expect(playerState.currentTrack?.id, equals('song_123'));
      expect(playerState.isPlaying, isTrue);

      // Tapping again toggles playback (pause)
      await tester.tap(find.byType(TrackTile));
      await tester.pump();
      expect(playerState.isPlaying, isFalse);

      // Tapping again toggles playback (play)
      await tester.tap(find.byType(TrackTile));
      await tester.pump();
      expect(playerState.isPlaying, isTrue);

      playerState.dispose();
    });
  });
}
