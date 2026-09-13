import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(Uri.parse('https://raw.githubusercontent.com/sigma67/ytmusicapi/master/ytmusicapi/auth/browser.py'));
  print(res.body);
}

