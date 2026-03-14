import 'dart:io';

void main() {
  final html = File('spotify_dump.html').readAsStringSync();
  final regex = RegExp(r'<script id="([^"]+)" type="(application/json|text/plain)">(.+?)</script>');
  for (final match in regex.allMatches(html)) {
      print("Found script id: ${match.group(1)} with type: ${match.group(2)} - length: ${match.group(3)!.length}");
  }

  final regex2 = RegExp(r'<script id="__NEXT_DATA__" type="application/json">(.+?)</script>');
  final nextData = regex2.firstMatch(html);
  if (nextData != null) {
      print("__NEXT_DATA__ detected! length: ${nextData.group(1)!.length}");
      File('spotify_json.txt').writeAsStringSync(nextData.group(1)!);
  }
}
