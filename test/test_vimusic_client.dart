import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const vId = '3xjo8h14gCI';
  final client = http.Client();

  final payload = {
    'context': {
      'client': {
        'clientName': 'ANDROID_MUSIC',
        'clientVersion': '5.28.1',
        'platform': 'MOBILE',
        'androidSdkVersion': 30,
        'hl': 'en',
      }
    },
    'videoId': vId,
  };

  final uri = Uri.parse('https://music.youtube.com/youtubei/v1/player?prettyPrint=false');
  final res = await client.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
    },
    body: jsonEncode(payload),
  );

  print('Status: ${res.statusCode}');
  print('Body: ${res.body}');
  client.close();
}

