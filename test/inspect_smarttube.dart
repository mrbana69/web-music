import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(
    Uri.parse('https://raw.githubusercontent.com/yuliskov/MediaServiceCore/master/youtubeapi/src/main/java/com/liskovsoft/youtubeapi/app/potokencloud2/Constants.kt'),
  );
  print('potokencloud2: ${res.body}');
  final resApi = await http.get(
    Uri.parse('https://raw.githubusercontent.com/yuliskov/MediaServiceCore/master/youtubeapi/src/main/java/com/liskovsoft/youtubeapi/app/potokencloud2/PoTokenCloudApi.kt'),
  );
  print('PoTokenCloudApi: ${resApi.body}');
}

