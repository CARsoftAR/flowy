import 'dart:convert';
import 'package:http/http.dart' as http;

String _cleanTitle(String title) {
  return title
      .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '')
      .replaceAll(RegExp(r'official|video|audio|lyrics?|music', caseSensitive: false), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

void main() async {
  final client = http.Client();
  final titles = [
    'Bohemian Rhapsody',
    'Despacito',
  ];
  final artists = ['Queen Official', 'LuisFonsiVEVO']; // realistic YT channels

  for (int i = 0; i < titles.length; i++) {
    final title = _cleanTitle(titles[i]);
    final artist = artists[i];
    final q = '$title $artist';
    final uri = Uri.parse('https://lrclib.net/api/search').replace(queryParameters: {
      'q': q,
    });
    
    print('Fetching $uri');
    final response = await client.get(uri, headers: {'User-Agent': 'Flowy/1.0'});
    print('Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final jsonList = jsonDecode(response.body) as List<dynamic>;
      print('Found ${jsonList.length} results');
      if (jsonList.isNotEmpty) {
        final hasSynced = jsonList[0]['syncedLyrics'] != null;
        print('First result has syncedLyrics: $hasSynced');
      }
    } else {
      print('Body: ${response.body}');
    }
    print('---');
  }
  client.close();
}
