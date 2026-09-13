import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final client = http.Client();
  final uri = Uri.parse('https://music.youtube.com/youtubei/v1/browse?prettyPrint=false');

  for (final id in ['VLLM', 'FEmusic_liked_videos', 'FEmusic_liked_playlists']) {
    final payload = jsonEncode({
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20241101.01.00',
          'hl': 'it',
          'gl': 'IT',
        }
      },
      'browseId': id,
    });

    final headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
      'Origin': 'https://music.youtube.com',
      'Referer': 'https://music.youtube.com/',
    };

    final res = await client.post(uri, headers: headers, body: payload);
    final data = jsonDecode(res.body);
    print('\n================ $id ================');
    final singleCol = data['contents']?['singleColumnBrowseResultsRenderer'];
    if (singleCol != null) {
      final tabs = singleCol['tabs'] as List? ?? [];
      print('Tabs count: ${tabs.length}');
      for (int t = 0; t < tabs.length; t++) {
        final tab = tabs[t]['tabRenderer'];
        print('Tab $t title: ${tab?['title']}');
        final content = tab?['content'];
        print('  Tab content keys: ${(content as Map?)?.keys.toList()}');
        
        final secList = content?['sectionListRenderer']?['contents'] as List? ?? [];
        print('  secList count: ${secList.length}');
        for (int s = 0; s < secList.length; s++) {
          final sec = secList[s] as Map;
          print('    sec $s keys: ${sec.keys.toList()}');
          if (sec['itemSectionRenderer'] != null) {
            final itemSecContents = sec['itemSectionRenderer']['contents'] as List? ?? [];
            print('      itemSectionRenderer contents: ${itemSecContents.length}');
            for (final ic in itemSecContents) {
              print('        ic keys: ${(ic as Map).keys.toList()}');
              if (ic['gridRenderer'] != null) {
                print('        gridRenderer items: ${(ic['gridRenderer']['items'] as List?)?.length}');
              }
              if (ic['musicPlaylistShelfRenderer'] != null) {
                print('        musicPlaylistShelfRenderer contents: ${(ic['musicPlaylistShelfRenderer']['contents'] as List?)?.length}');
              }
              if (ic['musicShelfRenderer'] != null) {
                print('        musicShelfRenderer contents: ${(ic['musicShelfRenderer']['contents'] as List?)?.length}');
              }
            }
          }
          if (sec['musicPlaylistShelfRenderer'] != null) {
            final plContents = sec['musicPlaylistShelfRenderer']['contents'] as List? ?? [];
            print('      musicPlaylistShelfRenderer direct: ${plContents.length} items');
          }
          if (sec['musicShelfRenderer'] != null) {
            final shContents = sec['musicShelfRenderer']['contents'] as List? ?? [];
            print('      musicShelfRenderer direct: ${shContents.length} items');
          }
          if (sec['gridRenderer'] != null) {
            final gContents = sec['gridRenderer']['items'] as List? ?? [];
            print('      gridRenderer direct: ${gContents.length} items');
          }
        }
      }
    }
  }

  client.close();
}

