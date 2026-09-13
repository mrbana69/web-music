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

  void findNodes(dynamic obj, bool Function(Map) predicate, List<Map> matches) {
    if (obj is Map) {
      if (predicate(obj)) matches.add(obj);
      for (final v in obj.values) findNodes(v, predicate, matches);
    } else if (obj is List) {
      for (final item in obj) findNodes(item, predicate, matches);
    }
  }

  // 1. Test Artist: Shiva (UCG8dba9iFwcp5UYB76Eu3gA)
  print('--- Testing Artist ---');
  final artistRes = await client.post(
    Uri.parse('https://music.youtube.com/youtubei/v1/browse?prettyPrint=false'),
    headers: headers,
    body: jsonEncode({'context': context, 'browseId': 'UCG8dba9iFwcp5UYB76Eu3gA'}),
  );
  if (artistRes.statusCode == 200) {
    final data = jsonDecode(artistRes.body);
    final trackNodes = <Map>[];
    findNodes(data, (m) => m.containsKey('musicResponsiveListItemRenderer'), trackNodes);
    print('Artist track nodes: ${trackNodes.length}');

    final albumNodes = <Map>[];
    findNodes(data, (m) => m.containsKey('musicTwoRowItemRenderer'), albumNodes);
    print('Artist album/single nodes: ${albumNodes.length}');
  }

  // 2. Test Album: MPREb_2P4CQKzXZha
  print('\n--- Testing Album ---');
  final albumRes = await client.post(
    Uri.parse('https://music.youtube.com/youtubei/v1/browse?prettyPrint=false'),
    headers: headers,
    body: jsonEncode({'context': context, 'browseId': 'MPREb_2P4CQKzXZha'}),
  );
  if (albumRes.statusCode == 200) {
    final data = jsonDecode(albumRes.body);
    final trackNodes = <Map>[];
    findNodes(data, (m) => m.containsKey('musicResponsiveListItemRenderer'), trackNodes);
    print('Album track nodes: ${trackNodes.length}');
  }

  // 3. Test Playlist: VLPLjCJkgSTFOePtpxbllwZeFOuwmqOUTOTJ
  print('\n--- Testing Playlist ---');
  final plRes = await client.post(
    Uri.parse('https://music.youtube.com/youtubei/v1/browse?prettyPrint=false'),
    headers: headers,
    body: jsonEncode({'context': context, 'browseId': 'VLPLjCJkgSTFOePtpxbllwZeFOuwmqOUTOTJ'}),
  );
  if (plRes.statusCode == 200) {
    final data = jsonDecode(plRes.body);
    final trackNodes = <Map>[];
    findNodes(data, (m) => m.containsKey('musicResponsiveListItemRenderer'), trackNodes);
    print('Playlist track nodes: ${trackNodes.length}');
  }
}
