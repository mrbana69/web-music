import 'dart:convert';
import 'package:http/http.dart' as http;

List<Map<String, dynamic>> findNodes(dynamic node, String key) {
  final results = <Map<String, dynamic>>[];
  void search(dynamic current) {
    if (current is Map) {
      if (current.containsKey(key) && current[key] is Map) {
        results.add(Map<String, dynamic>.from(current[key]));
      }
      for (final val in current.values) {
        search(val);
      }
    } else if (current is List) {
      for (final item in current) {
        search(item);
      }
    }
  }
  search(node);
  return results;
}

void main() async {
  final client = http.Client();
  final query = 'Sfera Ebbasta';

  final uri = Uri.parse('https://music.youtube.com/youtubei/v1/search?prettyPrint=false');
  final payload = jsonEncode({
    'context': {
      'client': {
        'clientName': 'WEB_REMIX',
        'clientVersion': '1.20241101.01.00',
        'hl': 'it',
        'gl': 'IT',
      },
      'user': {},
    },
    'query': query,
  });

  final headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
    'Origin': 'https://music.youtube.com',
  };

  final res = await client.post(uri, headers: headers, body: payload);
  final data = jsonDecode(res.body);

  final tracks = <String>[];
  final artists = <String>[];
  final albums = <String>[];

  // Card shelf
  final cardShelves = findNodes(data, 'musicCardShelfRenderer');
  for (final card in cardShelves) {
    final title = card['title']?['runs']?[0]?['text']?.toString() ?? '';
    if (title.isNotEmpty) artists.add('Card Artist: $title');
    final contents = card['contents'] as List? ?? [];
    for (final c in contents) {
      final r = c['musicResponsiveListItemRenderer'];
      final col0 = (r['flexColumns'][0] as Map)['musicResponsiveListItemFlexColumnRenderer'];
      final songTitle = col0['text']['runs'][0]['text'];
      tracks.add('Card Song: $songTitle');
    }
  }

  // Responsive items
  final responsiveItems = findNodes(data, 'musicResponsiveListItemRenderer');
  for (final item in responsiveItems) {
    final flexCols = item['flexColumns'] as List? ?? [];
    if (flexCols.isEmpty) continue;
    final col0 = (flexCols[0] as Map)['musicResponsiveListItemFlexColumnRenderer'];
    final t = col0?['text']?['runs']?[0]?['text']?.toString() ?? '';
    final col1 = flexCols.length > 1 ? (flexCols[1] as Map)['musicResponsiveListItemFlexColumnRenderer'] : null;
    final sub = ((col1?['text']?['runs'] as List?) ?? []).map((r) => r['text']).join('');
    
    if (sub.toLowerCase().contains('brano') || sub.toLowerCase().contains('video')) {
      if (!tracks.contains(t)) tracks.add(t);
    } else if (sub.toLowerCase().contains('album') || sub.toLowerCase().contains('singolo') || sub.toLowerCase().contains('ep')) {
      if (!albums.contains(t)) albums.add(t);
    } else if (sub.toLowerCase().contains('artista')) {
      if (!artists.contains(t)) artists.add(t);
    } else {
      if (!tracks.contains(t)) tracks.add(t);
    }
  }

  print('Total Tracks: ${tracks.length}');
  print('Total Artists: ${artists.length}');
  print('Total Albums: ${albums.length}');
  print('\nFirst 5 tracks: ${tracks.take(5).toList()}');
  print('First 3 artists: ${artists.take(3).toList()}');
  print('First 3 albums: ${albums.take(3).toList()}');

  client.close();
}

