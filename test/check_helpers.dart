import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(Uri.parse('https://raw.githubusercontent.com/sigma67/ytmusicapi/master/ytmusicapi/helpers.py'));
  for (final l in res.body.split('\n')) {
    if (l.toLowerCase().contains('sapisid') || l.toLowerCase().contains('auth') || l.toLowerCase().contains('header')) {
      print(l);
    }
  }
}

