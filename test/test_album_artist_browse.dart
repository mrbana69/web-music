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

void main() {
  test('Test album and artist browsing edge cases', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _RealHttpOverrides();
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    final api = ApiService(storage);

    print('--- Case 1: fetchArtist with Channel ID ---');
    final a1 = await api.fetchArtist('UC3cvw22UbTYbH63m_9a_tAQ');
    print('a1: ${a1?.name}, topTracks=${a1?.topTracks.length}, albums=${a1?.albums.length}');
    if (a1 != null && a1.albums.isNotEmpty) {
      for (final alb in a1.albums.take(3)) {
        print('  Artist album: title="${alb.title}", id="${alb.id}", artistName="${alb.artistName}"');
        final fetchedAlb = await api.fetchAlbum(alb.id);
        print('    -> fetchAlbum("${alb.id}") result: ${fetchedAlb != null ? "SUCCESS (tracks: ${fetchedAlb.tracks.length}, artist: ${fetchedAlb.artistName})" : "NULL/FAILED"}');
      }
    }

    print('\n--- Case 2: fetchArtist with Name instead of ID ---');
    final a2 = await api.fetchArtist('BLANCO');
    print('a2: ${a2?.name}');

    print('\n--- Case 3: Search albums and check header & artist extraction ---');
    final s = await api.search('Innamorato', filter: 'albums');
    final searchAlbums = s['albums'] ?? [];
    print('Found search albums: ${searchAlbums.length}');
    for (final alb in searchAlbums.take(3)) {
      print('  Search album: title="${alb.title}", id="${alb.id}", artistName="${alb.artistName}", cover="${alb.coverUrl}"');
      final fetchedAlb = await api.fetchAlbum(alb.id);
      if (fetchedAlb != null) {
        print('    -> fetchAlbum OK: title="${fetchedAlb.title}", artistName="${fetchedAlb.artistName}", artistId="${fetchedAlb.artistId}", cover="${fetchedAlb.coverUrl}", year="${fetchedAlb.year}", tracks=${fetchedAlb.tracks.length}');
      } else {
        print('    -> fetchAlbum FAILED/NULL for id="${alb.id}"');
      }
    }

    print('\n--- Case 4: Search "Blanco" and check artists and albums ---');
    final sAll = await api.search('Blanco', filter: 'all');
    for (final art in (sAll['artists'] ?? []).take(3)) {
      print('  Artist from all: name="${art.name}", id="${art.id}", picture="${art.picture}"');
      final fetchedArt = await api.fetchArtist(art.id);
      print('    -> fetchArtist OK: ${fetchedArt != null ? "topTracks=${fetchedArt.topTracks.length}, albums=${fetchedArt.albums.length}" : "FAILED"}');
    }
    for (final alb in (sAll['albums'] ?? []).take(3)) {
      print('  Album from all: title="${alb.title}", id="${alb.id}", artistName="${alb.artistName}", cover="${alb.coverUrl}"');
      final fetchedAlb = await api.fetchAlbum(alb.id);
      print('    -> fetchAlbum OK: ${fetchedAlb != null ? "tracks=${fetchedAlb.tracks.length}, artist=${fetchedAlb.artistName}" : "FAILED"}');
    }

    print('\n--- Case 5: fetchAlbum with OLAK5uy_ and VL playlist IDs ---');
    // Common album playlist IDs in YouTube Music
    final albPlaylists = ['OLAK5uy_mN25rQx52fXg1z8y2LSm1zZtJ1U9p0c58', 'OLAK5uy_k1bN4PzV_3k0_4M6X3D0E-Xk0g9W0PqU'];
    for (final pId in albPlaylists) {
      final fetched = await api.fetchAlbum(pId);
      print('  fetchAlbum("$pId"): ${fetched != null ? "SUCCESS (tracks: ${fetched.tracks.length}, title: ${fetched.title})" : "NULL/FAILED"}');
    }
  });
}
