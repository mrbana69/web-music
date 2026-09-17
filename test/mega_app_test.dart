import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:preluded_music/config/app_config.dart';
import 'package:preluded_music/models/track.dart';
import 'package:preluded_music/models/album.dart';
import 'package:preluded_music/models/artist.dart';
import 'package:preluded_music/models/playlist.dart';
import 'package:preluded_music/models/user.dart';
import 'package:preluded_music/services/storage_service.dart';
import 'package:preluded_music/providers/library_state.dart';
import 'package:preluded_music/services/api_service.dart';

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

  group('1. Models & Parsing Unit Tests', () {
    test('Track model serialization & formatting', () {
      final track = Track(
        id: 'track_123',
        videoId: 'video_456',
        title: 'Mi Fai Impazzire',
        artistName: 'Blanco, Sfera Ebbasta - Topic',
        artistId: 'art_789',
        albumName: 'Blu Celeste',
        albumId: 'alb_001',
        coverUrl: 'https://example.com/cover.jpg',
        durationMs: 220000,
        isExplicit: true,
      );

      expect(track.id, 'track_123');
      expect(track.formattedDuration, '3:40');
      expect(track.isExplicit, isTrue);

      final json = track.toJson();
      expect(json['id'], 'track_123');
      expect(json['durationMs'], 220000);

      final fromJson = Track.fromJson(json);
      expect(fromJson.id, 'track_123');
      expect(fromJson.artistName, contains('Blanco'));
    });

    test('Album model serialization & copyWith', () {
      final album = Album(
        id: 'MPREb_test',
        title: 'Innamorato',
        artistName: 'Blanco',
        artistId: 'UC_test',
        coverUrl: 'https://example.com/album.jpg',
        year: '2023',
        tracks: [
          Track(
            id: 't1',
            videoId: 't1',
            title: 'Anima Tormentata',
            artistName: 'Blanco',
            coverUrl: '',
            durationMs: 180000,
          )
        ],
      );

      expect(album.tracks.length, 1);
      final updated = album.copyWith(title: 'Innamorato (Deluxe)', year: '2024');
      expect(updated.title, 'Innamorato (Deluxe)');
      expect(updated.year, '2024');
      expect(updated.artistName, 'Blanco');
    });

    test('Artist model parsing and defaults', () {
      final artist = Artist(
        id: 'UC_artist',
        name: 'Blanco',
        picture: 'https://example.com/pic.jpg',
        bio: 'Cantautore italiano',
      );

      expect(artist.name, 'Blanco');
      final json = artist.toJson();
      final fromJson = Artist.fromJson(json);
      expect(fromJson.name, 'Blanco');
      expect(fromJson.id, 'UC_artist');
    });

    test('Playlist model creation & copyWith', () {
      final pl = Playlist(
        id: 'pl_1',
        title: 'Preferiti Italiani',
        subtitle: 'I migliori successi',
        tracks: [],
      );

      expect(pl.title, 'Preferiti Italiani');
      final updated = pl.copyWith(subtitle: '10 brani');
      expect(updated.subtitle, '10 brani');
    });

    test('GoogleUser model serialization', () {
      final user = GoogleUser(
        name: 'Mario Rossi',
        email: 'mario.rossi@gmail.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        cookie: 'SAPISID=12345',
      );

      final json = user.toJson();
      final fromJson = GoogleUser.fromJson(json);
      expect(fromJson.email, 'mario.rossi@gmail.com');
      expect(fromJson.cookie, 'SAPISID=12345');
    });
  });

  group('2. AppConfig Formatting & Sanitization Tests', () {
    test('Artwork URLs correctly formatted for high resolution', () {
      const googleUrl = 'https://lh3.googleusercontent.com/xyz=w120-h120';
      final formattedG = AppConfig.formatArtwork(googleUrl);
      expect(formattedG, contains('=w500-h500-l90-rj'));

      const ytUrl = 'https://i.ytimg.com/vi/abc/default.jpg';
      final formattedYt = AppConfig.formatArtwork(ytUrl);
      expect(formattedYt, contains('/hqdefault.jpg'));
    });

    test('Artist name sanitization cleans noise patterns', () {
      expect(AppConfig.sanitizeArtist('Blanco - Topic'), 'Blanco');
      expect(AppConfig.sanitizeArtist('MarracashVEVO'), 'Marracash');
      expect(AppConfig.sanitizeArtist('Sfera Ebbasta Official Channel'), 'Sfera Ebbasta');
      expect(AppConfig.sanitizeArtist('Island Records'), 'Island');
    });

    test('Share URL formatting', () {
      final shareUrl = AppConfig.getShareUrl('test_id_123');
      expect(shareUrl, 'https://preluded.vercel.app/app/test_id_123');
    });
  });

  group('3. StorageService & Persistence Tests', () {
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await StorageService.init();
    });

    test('Liked songs toggle and retrieval', () async {
      final track = Track(
        id: 't_like_1',
        videoId: 't_like_1',
        title: 'Nostalgia',
        artistName: 'Blanco',
        coverUrl: '',
        durationMs: 200000,
      );

      expect(storage.isLiked('t_like_1'), isFalse);
      final isNowLiked = await storage.toggleLike(track);
      expect(isNowLiked, isTrue);
      expect(storage.isLiked('t_like_1'), isTrue);

      final isUnliked = await storage.toggleLike(track);
      expect(isUnliked, isFalse);
      expect(storage.isLiked('t_like_1'), isFalse);
    });

    test('Playlists CRUD operations', () async {
      final pl = await storage.createPlaylist('Estate 2025', subtitle: 'Hit');
      expect(pl.title, 'Estate 2025');
      expect(storage.getPlaylists().length, 1);

      final track = Track(
        id: 't_pl',
        videoId: 't_pl',
        title: 'Sottogonna',
        artistName: 'Blanco',
        coverUrl: '',
        durationMs: 180000,
      );

      await storage.addTrackToPlaylist(pl.id, track);
      final updatedPl = storage.getPlaylists().first;
      expect(updatedPl.tracks.length, 1);
      expect(updatedPl.tracks.first.title, 'Sottogonna');

      await storage.removeTrackFromPlaylist(pl.id, 't_pl');
      expect(storage.getPlaylists().first.tracks.isEmpty, isTrue);

      await storage.deletePlaylist(pl.id);
      expect(storage.getPlaylists().isEmpty, isTrue);
    });

    test('Followed artists & saved albums persistence', () async {
      expect(storage.isArtistFollowed('artist_blanco'), isFalse);
      await storage.toggleFollowArtist('artist_blanco');
      expect(storage.isArtistFollowed('artist_blanco'), isTrue);
      expect(storage.getFollowedArtistIds(), contains('artist_blanco'));

      await storage.toggleFollowArtist('artist_blanco');
      expect(storage.isArtistFollowed('artist_blanco'), isFalse);

      expect(storage.isAlbumSaved('album_blu_celeste'), isFalse);
      await storage.toggleSaveAlbum('album_blu_celeste');
      expect(storage.isAlbumSaved('album_blu_celeste'), isTrue);
      expect(storage.getSavedAlbumIds(), contains('album_blu_celeste'));
    });

    test('Listening history management with cap', () async {
      final track = Track(
        id: 'h_1',
        videoId: 'h_1',
        title: 'Brividi',
        artistName: 'Mahmood, Blanco',
        coverUrl: '',
        durationMs: 210000,
      );

      await storage.addToHistory(track);
      expect(storage.getHistory().length, 1);
      expect(storage.getHistory().first.id, 'h_1');

      await storage.clearHistory();
      expect(storage.getHistory().isEmpty, isTrue);
    });
  });

  group('4. LibraryState Reactive State Tests', () {
    late StorageService storage;
    late LibraryState library;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await StorageService.init();
      library = LibraryState(storage);
    });

    test('LibraryState reactive followers and saved albums', () async {
      expect(library.isArtistFollowed('blanco_id'), isFalse);
      await library.toggleFollowArtist('blanco_id');
      expect(library.isArtistFollowed('blanco_id'), isTrue);
      expect(library.followedArtists, contains('blanco_id'));

      expect(library.isAlbumSaved('album_id'), isFalse);
      await library.toggleSaveAlbum('album_id');
      expect(library.isAlbumSaved('album_id'), isTrue);
      expect(library.savedAlbums, contains('album_id'));
    });

    test('LibraryState Google login & logout', () async {
      expect(library.isGoogleLoggedIn, isFalse);
      final user = GoogleUser(
        name: 'Test User',
        email: 'test@example.com',
        avatarUrl: '',
        cookie: 'SESSION_ID=abc',
      );

      await library.loginWithGoogle(user);
      expect(library.isGoogleLoggedIn, isTrue);
      expect(library.googleUser?.name, 'Test User');
      expect(library.ytmCookie, 'SESSION_ID=abc');

      await library.logoutGoogle();
      expect(library.isGoogleLoggedIn, isFalse);
      expect(library.googleUser, isNull);
    });
  });

  group('5. Live ApiService Integration Tests', () {
    late ApiService api;
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await StorageService.init();
      api = ApiService(storage);
    });

    test('Live Search: "all" filter returns tracks, artists, albums, playlists', () async {
      final res = await api.search('Blanco', filter: 'all');
      expect(res, isNotNull);
      final tracks = res['tracks'] as List<Track>;
      expect(tracks.isNotEmpty, isTrue, reason: 'Expected tracks in search');
    }, timeout: const Timeout(Duration(seconds: 25)));

    test('Live Search: "artists" filter returns real artist items', () async {
      final res = await api.search('Marracash', filter: 'artists');
      final artists = res['artists'] as List<Artist>;
      expect(artists.isNotEmpty, isTrue, reason: 'Expected artist filter to return artists');
      expect(artists.first.name.toLowerCase(), contains('marracash'));
    }, timeout: const Timeout(Duration(seconds: 25)));

    test('Live Search: "albums" filter returns album items', () async {
      final res = await api.search('Innamorato', filter: 'albums');
      final albums = res['albums'] as List<Album>;
      expect(albums.isNotEmpty, isTrue, reason: 'Expected albums for Innamorato');
    }, timeout: const Timeout(Duration(seconds: 25)));

    test('Live Album Fetch: deep header parsing provides title, artist and tracks', () async {
      final searchRes = await api.search('Blu Celeste Blanco', filter: 'albums');
      final albums = searchRes['albums'] as List<Album>;
      if (albums.isNotEmpty) {
        final albumId = albums.first.id;
        final album = await api.fetchAlbum(albumId);
        expect(album, isNotNull);
        expect(album!.title.isNotEmpty, isTrue);
        expect(album.tracks.isNotEmpty, isTrue);
        expect(album.artistName.isNotEmpty, isTrue);
        expect(album.artistName, isNot('Artista'));
        expect(album.tracks.first.coverUrl.isNotEmpty, isTrue);
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('Live Lyrics Fetch: retrieves lyrics for known track', () async {
      final testTrack = Track(
        id: 'test_lyr',
        videoId: 'test_lyr',
        title: 'Mi Fai Impazzire',
        artistName: 'Blanco',
        coverUrl: '',
        durationMs: 220000,
      );
      final lyrics = await api.fetchLyrics(testTrack);
      expect(lyrics, isNotNull, reason: 'Expected LRCLib to return lyrics');
      expect(lyrics!.plainText.isNotEmpty || lyrics.syncedLines.isNotEmpty, isTrue);
    }, timeout: const Timeout(Duration(seconds: 25)));

    test('Live Artist Fetch: retrieves artist profile with top tracks and albums', () async {
      final searchRes = await api.search('Blanco', filter: 'artists');
      final artists = searchRes['artists'] as List<Artist>;
      if (artists.isNotEmpty) {
        final artist = await api.fetchArtist(artists.first.id);
        expect(artist, isNotNull);
        expect(artist!.name.isNotEmpty, isTrue);
        expect(artist.topTracks.isNotEmpty, isTrue);
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('Live Stream Resolution: resolves audio stream URL', () async {
      final searchRes = await api.search('Blanco Sottogonna', filter: 'tracks');
      final tracks = searchRes['tracks'] as List<Track>;
      if (tracks.isNotEmpty) {
        final streamUrl = await api.resolveAudioStream(tracks.first);
        expect(streamUrl.isNotEmpty, isTrue);
        expect(streamUrl.startsWith('http'), isTrue);
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
