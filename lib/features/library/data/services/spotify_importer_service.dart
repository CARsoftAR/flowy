import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../domain/entities/entities.dart';
import '../../../../domain/repositories/repositories.dart';

class SpotifyTrackMetadata {
  final String title;
  final String artist;
  final String? coverUrl;

  SpotifyTrackMetadata({
    required this.title,
    required this.artist,
    this.coverUrl,
  });
}

class SpotifyPlaylistInfo {
  final String title;
  final String? coverUrl;
  final List<SpotifyTrackMetadata> tracks;

  SpotifyPlaylistInfo({
    required this.title,
    this.coverUrl,
    required this.tracks,
  });
}

class SpotifyImporterService {
  final MusicRepository _musicRepo;

  SpotifyImporterService(this._musicRepo);

  /// Extract Playlist ID from URL
  String? _extractPlaylistId(String url) {
    if (url.contains('spotify.com/playlist/')) {
      final parts = url.split('spotify.com/playlist/');
      if (parts.length > 1) {
        final idPart = parts[1].split('?')[0];
        return idPart;
      }
    }
    return null;
  }

  /// Fetch playlist metadata directly from Spotify Web
  Future<SpotifyPlaylistInfo?> fetchPlaylistData(String url) async {
    final playlistId = _extractPlaylistId(url);
    if (playlistId == null) return null;

    final embedUrl = Uri.parse('https://open.spotify.com/embed/playlist/$playlistId');
    try {
      final response = await http.get(embedUrl, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      });

      if (response.statusCode != 200) return null;

      final html = response.body;

      final regex = RegExp(r'<script id="__NEXT_DATA__" type="application/json">(.+?)</script>');
      final match = regex.firstMatch(html);
      
      if (match == null) return null;

      final jsonStr = match.group(1)!;
      final json = jsonDecode(jsonStr);

      final entity = json['props']?['pageProps']?['state']?['data']?['entity'];
      if (entity == null) return null;

      final playlistName = entity['name'] ?? 'Spotify Playlist';
      
      String? coverUrl;
      if (entity['coverArt']?['sources'] != null && (entity['coverArt']['sources'] as List).isNotEmpty) {
        coverUrl = entity['coverArt']['sources'][0]['url'];
      }

      final trackList = entity['trackList'] as List?;
      if (trackList == null) return null;

      List<SpotifyTrackMetadata> extractedTracks = [];
      for (final track in trackList) {
        final title = track['title'];
        final subtitle = track['subtitle']; // artist
        
        if (title != null) {
          extractedTracks.add(SpotifyTrackMetadata(
            title: title.toString(),
            artist: subtitle?.toString() ?? 'Desconocido',
          ));
        }
      }

      return SpotifyPlaylistInfo(title: playlistName, coverUrl: coverUrl, tracks: extractedTracks);

    } catch (e) {
      print('Spotify Importer Error: $e');
      return null;
    }
  }

  /// Search for each track on YouTube yielding as stream
  Stream<SongEntity?> searchAndProcessTracks(List<SpotifyTrackMetadata> tracks) async* {
    for (final track in tracks) {
      final query = '${track.title} ${track.artist}';
      
      // Delay barely to avoid rate limits
      await Future.delayed(const Duration(milliseconds: 300));
      
      final result = await _musicRepo.search(query);
      SongEntity? matchedSong;
      result.fold(
        (failure) {},
        (searchResults) {
          if (searchResults.songs.isNotEmpty) {
            matchedSong = searchResults.songs.first;
          }
        }
      );
      
      yield matchedSong;
    }
  }
}
