import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  const vId = '3xjo8h14gCI';
  final client = http.Client();

  final instances = [
    'https://invidious.nerdvpn.de',
    'https://yewtu.be',
    'https://inv.nadeko.net',
    'https://invidious.drgns.space',
    'https://vid.priv.au',
    'https://invidious.no-valis.be',
    'https://invidious.protokolla.fi',
  ];

  for (final inst in instances) {
    try {
      print('\nTesting Invidious instance: $inst');
      // Invidious proxy stream URL
      final proxyStreamUrl = '$inst/latest_version?id=$vId&itag=140&local=true';
      final req = await HttpClient().getUrl(Uri.parse(proxyStreamUrl));
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=1200000-1500000');
      final res = await req.close().timeout(const Duration(seconds: 6));
      print('  Status: ${res.statusCode}');
      if (res.statusCode == 206 || res.statusCode == 200) {
        print('  🎉 SUCCESS! $inst supports local=true proxy audio past 1MB!');
        await res.drain();
        break;
      }
      await res.drain();
    } catch (e) {
      print('  Error: $e');
    }
  }

  client.close();
}

