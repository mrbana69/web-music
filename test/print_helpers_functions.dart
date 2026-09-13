import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(Uri.parse('https://raw.githubusercontent.com/sigma67/ytmusicapi/master/ytmusicapi/helpers.py'));
  final lines = res.body.split('\n');
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('sapisid_from_cookie') || lines[i].contains('get_authorization') || lines[i].contains('initialize_headers')) {
      print(lines.sublist(i, (i + 25).clamp(0, lines.length)).join('\n'));
      print('-------------------');
    }
  }
}

