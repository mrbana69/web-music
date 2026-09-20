import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:preluded_music/services/storage_service.dart';
import 'package:preluded_music/services/api_service.dart';

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();
  SharedPreferences.setMockInitialValues({});
  final storage = await StorageService.init();
  final api = ApiService(storage);

  print('=== TEST 1: Search Artists ===');
  final searchArtists = await api.search('Blanco', filter: 'artists');
  final artists = searchArtists['artists'];
  print('Found artists count: ${artists.length}');
  for (final a in artists.take(3)) {
    print('Artist: name="${a.name}", id="${a.id}", picture="${a.picture}"');
    print('Fetching artist details for id="${a.id}"...');
    final full = await api.fetchArtist(a.id);
    if (full == null) {
      print('FAILED: fetchArtist returned null!');
    } else {
      print('SUCCESS: name="${full.name}", topTracks=${full.topTracks.length}, albums=${full.albums.length}');
      if (full.topTracks.isNotEmpty) {
        print('Sample track: ${full.topTracks.first.title}');
      }
      if (full.albums.isNotEmpty) {
        print('Sample album: ${full.albums.first.title} (id: ${full.albums.first.id})');
      }
    }
  }

  print('\n=== TEST 2: Search Albums ===');
  final searchAlbums = await api.search('Innamorato', filter: 'albums');
  final albums = searchAlbums['albums'];
  print('Found albums count: ${albums.length}');
  for (final alb in albums.take(3)) {
    print('Album: title="${alb.title}", id="${alb.id}", artist="${alb.artistName}", cover="${alb.coverUrl}"');
    print('Fetching album details for id="${alb.id}"...');
    final fullAlb = await api.fetchAlbum(alb.id);
    if (fullAlb == null) {
      print('FAILED: fetchAlbum returned null!');
    } else {
      print('SUCCESS: title="${fullAlb.title}", artist="${fullAlb.artistName}", year="${fullAlb.year}", tracks=${fullAlb.tracks.length}');
      if (fullAlb.tracks.isNotEmpty) {
        print('Sample track: ${fullAlb.tracks.first.title} (artist: ${fullAlb.tracks.first.artistName}, duration: ${fullAlb.tracks.first.durationMs})');
      }
    }
  }

  print('\n=== TEST 3: Search All ===');
  final searchAll = await api.search('Blanco', filter: 'all');
  print('All tracks: ${searchAll['tracks'].length}');
  print('All artists: ${searchAll['artists'].length}');
  print('All albums: ${searchAll['albums'].length}');
  print('All playlists: ${searchAll['playlists'].length}');
}

