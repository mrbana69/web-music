import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Let's search GitHub or check Innertube / ytmusicapi for sapisid
  final urls = [
    'https://raw.githubusercontent.com/sigma67/ytmusicapi/master/ytmusicapi/auth/browser.py',
    'https://raw.githubusercontent.com/vfsfitvnm/ViMusic/master/app/src/main/java/it/vfsfitvnm/vimusic/service/PlayerService.kt',
    'https://raw.githubusercontent.com/fast4x/RiMusic/master/composeApp/src/commonMain/kotlin/it/fast4x/rimusic/utils/CookieHelper.kt',
  ];

  for (final url in urls) {
    try {
      final res = await http.get(Uri.parse(url));
      print('URL: $url -> Status: ${res.statusCode}');
      if (res.statusCode == 200) {
        final lines = res.body.split('\n');
        for (final l in lines) {
          if (l.toLowerCase().contains('sapisid') || l.toLowerCase().contains('authorization')) {
            print('  $l');
          }
        }
      }
    } catch (e) {
      print('Error on $url: $e');
    }
  }
}

