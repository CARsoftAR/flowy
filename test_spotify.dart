import 'dart:io';
import 'package:http/http.dart' as http;

class MyHttpOverrides extends HttpOverrides{
  @override
  HttpClient createHttpClient(SecurityContext? context){
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port)=> true;
  }
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();

  // Try the open API / embed API
  final url = Uri.parse('https://open.spotify.com/embed/playlist/37i9dQZF1DXcBWIGoYBM5M');
  final response = await http.get(url, headers: {
    'User-Agent': 'Mozilla/5.0',
  });
  File('spotify_dump.html').writeAsStringSync(response.body);
  print(response.statusCode);
}
