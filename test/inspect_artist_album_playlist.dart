import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final client = http.Client();
  final headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
    'Origin': 'https://music.youtube.com',
    'Referer': 'https://music.youtube.com/',
    'X-YouTube-Client-Name': '67',
    'X-YouTube-Client-Version': '1.20241101.01.00',
  };

  final context = {
    'client': {
      'clientName': 'WEB_REMIX',
      'clientVersion': '1.20241101.01.00',
      'hl': 'it',
      'gl': 'IT',
    }
  };

  // Search first to get browseIds
  final searchRes = await client.post(
    Uri.parse('https://music.youtube.com/youtubei/v1/search?prettyPrint=false'),
    headers: headers,
    body: jsonEncode({'context': context, 'query': 'Sfera Ebbasta'}),
  );
  final searchData = jsonDecode(searchRes.body);

  void findNodes(dynamic obj, bool Function(Map) predicate, List<Map> matches) {
    if (obj is Map) {
      if (predicate(obj)) matches.add(obj);
      for (final v in obj.values) findNodes(v, predicate, matches);
    } else if (obj is List) {
      for (final item in obj) findNodes(item, predicate, matches);
    }
  }

  final items = <Map>[];
  findNodes(searchData, (m) => m.containsKey('musicResponsiveListItemRenderer') || m.containsKey('musicTwoRowItemRenderer'), items);

  String? artistBrowseId;
  String? albumBrowseId;
  String? playlistBrowseId;

  for (final raw in items) {
    final m = (raw['musicResponsiveListItemRenderer'] ?? raw['musicTwoRowItemRenderer']) as Map;
    final nav = m['navigationEndpoint'] ?? m['title']?['runs']?[0]?['navigationEndpoint'];
    final bId = nav?['browseEndpoint']?['browseId']?.toString();
    final pageType = nav?['browseEndpoint']?['browseEndpointContextSupportedConfigs']?['browseEndpointContextMusicConfig']?['pageType']?.toString();
    final title = m['title']?['runs']?[0]?['text']?.toString();

    if (bId != null) {
      if (pageType == 'MUSIC_PAGE_TYPE_ARTIST' && artistBrowseId == null) {
        artistBrowseId = bId;
        print('Found Artist: $title -> browseId: $bId');
      }
      if (pageType == 'MUSIC_PAGE_TYPE_ALBUM' && albumBrowseId == null) {
        albumBrowseId = bId;
        print('Found Album: $title -> browseId: $bId');
      }
      if (pageType == 'MUSIC_PAGE_TYPE_PLAYLIST' && playlistBrowseId == null) {
        playlistBrowseId = bId;
        print('Found Playlist: $title -> browseId: $bId');
      }
    }
  }

  // Now test browse on each
  Future<void> testBrowse(String name, String? browseId) async {
    if (browseId == null) {
      print('No browseId for $name');
      return;
    }
    print('\n================ $name ($browseId) ================');
    final res = await client.post(
      Uri.parse('https://music.youtube.com/youtubei/v1/browse?prettyPrint=false'),
      headers: headers,
      body: jsonEncode({'context': context, 'browseId': browseId}),
    );
    print('Status: ${res.statusCode}, Body length: ${res.body.length}');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final tracks = <Map>[];
      findNodes(data, (m) => m.containsKey('musicResponsiveListItemRenderer'), tracks);
      print('Found ${tracks.length} musicResponsiveListItemRenderer');

      final twoRow = <Map>[];
      findNodes(data, (m) => m.containsKey('musicTwoRowItemRenderer'), twoRow);
      print('Found ${twoRow.length} musicTwoRowItemRenderer (albums/singles/etc.)');

      for (int i = 0; i < tracks.length && i < 5; i++) {
        final r = tracks[i]['musicResponsiveListItemRenderer'] as Map;
        final t = r['flexColumns']?[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']?[0]?['text'];
        final a = r['flexColumns']?[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']?[0]?['text'];
        final vid = r['playlistItemData']?['videoId'] ?? r['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId'];
        print('  Track $i: "$t" by "$a" (vid=$vid)');
      }
    }
  }

  await testBrowse('ARTIST', artistBrowseId);
  await testBrowse('ALBUM', albumBrowseId);
  await testBrowse('PLAYLIST', playlistBrowseId);
}
