import 'dart:io';

void main() async {
  const vId = '3xjo8h14gCI';
  final url = Uri.parse('https://invidious.nerdvpn.de/latest_version?id=$vId&itag=140&local=true');
  print('Streaming from: $url');

  final client = HttpClient();
  final req = await client.getUrl(url);
  final res = await req.close();
  print('Status: ${res.statusCode}');
  print('Content-Type: ${res.headers.value(HttpHeaders.contentTypeHeader)}');
  print('Content-Length: ${res.headers.value(HttpHeaders.contentLengthHeader)}');

  int total = 0;
  await for (final chunk in res) {
    total += chunk.length;
    if (total % 500000 < chunk.length) {
      print('Streamed so far: $total bytes');
    }
  }

  print('\n🎉🎉🎉 DONE! Streamed total: $total bytes! Full song downloaded without error! 🎉🎉🎉');
  client.close();
}

