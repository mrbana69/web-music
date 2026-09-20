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
  test('Test search filters across multiple queries', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _RealHttpOverrides();
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    final api = ApiService(storage);

    final queries = ['Taylor Swift', 'Sfera Ebbasta', 'Coldplay', 'Marracash', 'Queen'];

    for (final q in queries) {
      print('\n=== Query: "$q" ===');
      for (final filter in ['tracks', 'artists', 'albums', 'playlists', 'all']) {
        final res = await api.search(q, filter: filter);
        final t = (res['tracks'] as List).length;
        final a = (res['artists'] as List).length;
        final al = (res['albums'] as List).length;
        final p = (res['playlists'] as List).length;
        print('  filter="$filter" -> tracks=$t, artists=$a, albums=$al, playlists=$p');
        if (filter == 'artists' && a > 0) {
          final firstArt = (res['artists'] as List).first;
          print('    First artist: "${firstArt.name}", id="${firstArt.id}"');
        }
      }
    }
  });
}

