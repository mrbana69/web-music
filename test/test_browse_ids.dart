import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final client = http.Client();
  final uri = Uri.parse('https://music.youtube.com/youtubei/v1/browse?prettyPrint=false');

  final browseIds = [
    'FEmusic_library_landing',
    'FEmusic_library_corpus_tracks',
    'FEmusic_library_corpus_artists',
    'FEmusic_library_corpus_albums',
    'FEmusic_library_corpus_playlists',
    'FEmusic_liked_playlists',
    'FEmusic_liked_videos',
    'VLLM',
    'VLPL',
    'VLSE',
  ];

  for (final bId in browseIds) {
    final payload = jsonEncode({
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20241101.01.00',
          'hl': 'it',
          'gl': 'IT',
        }
      },
      'browseId': bId,
    });

    final headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
      'Origin': 'https://music.youtube.com',
    };

    final res = await client.post(uri, headers: headers, body: payload);
    print('$bId -> HTTP ${res.statusCode}');
  }

  client.close();
}

