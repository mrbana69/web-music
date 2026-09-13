import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(
    Uri.parse('https://raw.githubusercontent.com/fast4x/RiMusic/master/composeApp/src/androidMain/kotlin/it/fast4x/rimusic/extensions/webpotoken/PoTokenWebView.kt'),
  );
  print(res.body);
}

