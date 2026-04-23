import 'dart:async';
import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../core/network/flowy_http_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../services/flowy_engine.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../models/song_model.dart';
import '../datasources/lyrics_datasource.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MusicRepositoryImpl — concrete implementation using youtube_explode_dart
// ─────────────────────────────────────────────────────────────────────────────

class MusicRepositoryImpl implements MusicRepository {
  final YoutubeExplode _yt;
  final LyricsDataSource _lyricsSource;
  final Logger _log;

  // Simple in-memory stream URL cache keyed by videoId
  final Map<String, String> _streamCache = {};

  MusicRepositoryImpl({
    YoutubeExplode? youtubeExplode,
    LyricsDataSource? lyricsSource,
    Logger? logger,
  })  : _yt = youtubeExplode ?? YoutubeExplode(),
        _lyricsSource = lyricsSource ?? LyricsDataSource(),
        _log = logger ?? Logger();

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Validates if a string is likely a YouTube video ID.
  /// YouTube video IDs are exactly 11 characters.
  bool _isValidVideoId(String id) {
    if (id.length != 11) return false;
    // Check if it contains invalid characters for a video ID (alphanumeric, -, _)
    return !id.contains(RegExp(r'[^a-zA-Z0-9\-_]'));
  }

  // ── Search ────────────────────────────────────────────────────────────────

  @override
  FutureEither<SearchResultEntity> search(String query) async {
    try {
      final path = '/api/v1/search?q=${Uri.encodeComponent(query)}&type=video';
      final response = await FlowyEngine.performRequest(path);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (data.isEmpty) {
          _log.w('La respuesta está vacía');
          return Right(SearchResultEntity(query: query, songs: []));
        }

        final List<SongEntity> songs = data.map((item) {
          String? thumb;
          if (item['videoThumbnails'] != null &&
              (item['videoThumbnails'] as List).isNotEmpty) {
            thumb = item['videoThumbnails'][0]['url'];
          }
          return SongEntity(
            id: item['videoId'] ?? '',
            title: item['title'] ?? 'Sin título',
            artist: item['author'] ?? 'Artista desconocido',
            thumbnailUrl: thumb,
            duration: Duration(seconds: item['lengthSeconds'] ?? 0),
            isVideo: false, // Deshabilitamos video para volver a música pura
          );
        }).where((s) {
          if (!_isValidVideoId(s.id)) return false;
          // FILTRO ANTI-COMPILACIONES: Excluir videos de más de 15 minutos
          final maxDuration = const Duration(minutes: 15);
          if (s.duration > maxDuration) return false;
          return true;
        }).toList();

        _log.i('Invidious search OK: ${songs.length} results');
        return Right(SearchResultEntity(query: query, songs: songs));
      }
    } catch (e) {
      _log.w('Invidious search failed: $e. Falling back to native.');
    }

    // ── FALLBACK SEARCH: YoutubeExplode (Native) ─────────────────────────────
    try {
      final initialResults =
          await _yt.search.search(query).timeout(const Duration(seconds: 10));
      final allElements = await _fetchExtended(initialResults, 100);
      final songs = _mapToSongList(allElements);

      return Right(SearchResultEntity(query: query, songs: songs));
    } on TimeoutException {
      return Left(YoutubeFailure('La búsqueda tardó demasiado. Reintenta.'));
    } catch (e) {
      _log.e('Search error: $e');
      return Left(
          UnknownFailure('Servidor de búsqueda ocupado o error de red.'));
    }
  }

  // ── Suggestions ───────────────────────────────────────────────────────────

  @override
  FutureEither<List<String>> getSearchSuggestions(String query) async {
    // ── PRIMARY SUGGESTIONS: Invidious API (Dynamic) ──────────────────────────
    try {
      final baseUrl = FlowyEngine.currentApiUrl;
      final uri = Uri.parse(
          '$baseUrl/api/v1/suggestions?q=${Uri.encodeComponent(query)}');

      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('suggestions')) {
          final suggestions = List<String>.from(data['suggestions']);
          return Right(suggestions);
        }
      }
    } catch (e) {
      _log.w('Invidious suggestions failed: $e');
    }

    // ── FALLBACK SUGGESTIONS: YoutubeExplode (Native) ─────────────────────────
    try {
      final results = await _yt.search
          .getQuerySuggestions(query)
          .timeout(const Duration(seconds: 5));
      return Right(results);
    } catch (e) {
      return Left(YoutubeFailure('Suggestions failed'));
    }
  }

  // ── Stream URL ────────────────────────────────────────────────────────────

  @override
  FutureEither<String> getStreamUrl(String videoId,
      {bool isVideo = false}) async {
    if (!_isValidVideoId(videoId)) {
      return Left(YoutubeFailure('Invalid video ID format'));
    }

    // ── LISTA DE FALLBACKS: Múltiples instancias Invidious ─────────────
    final _invidiousInstances = [
      'https://inv.nadeko.net', // Chile - usually fastest
      'https://invidious.privacyredirect.com', // Privacy-based
      'https://yewtu.be', // Europe
      'https://invidious.nerdvpn.de', // Germany
      'https://invidious.no-logs.com', // Privacy
      'https://inv.tux.pizza', // US
      'https://iv.ggtyler.dev', // US
    ];

    String? lastError;

    // ── MOTOR 1: Invidious con fallback automático ───────────────────────
    for (final baseUrl in _invidiousInstances) {
      try {
        _log.d('Invidious: Probando $baseUrl para $videoId');

        final path = '/api/v1/videos/$videoId';
        final response = await FlowyEngine.performRequest(path);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          String? streamUrl;



          int? bestItag;
          final adaptiveFormats = data['adaptiveFormats'] as List<dynamic>?;

          if (bestItag == null && adaptiveFormats != null) {
            // Prioridad Audio: mp4 (AAC — codec nativo Android)
            final mp4Audio = adaptiveFormats!.where((f) {
              final type = f['type']?.toString() ?? '';
              return type.contains('audio') && type.contains('mp4');
            }).toList();

            if (mp4Audio.isNotEmpty) {
              mp4Audio.sort((a, b) => ((b['bitrate'] as num?)?.toInt() ?? 0)
                  .compareTo((a['bitrate'] as num?)?.toInt() ?? 0));
              bestItag = mp4Audio.first['itag'] as int?;
              _log.d('Invidious: itag MP4/AAC → $bestItag');
            }

            // Fallback: audio/webm (Opus)
            if (bestItag == null) {
              final webmAudio = adaptiveFormats!.where((f) {
                final type = f['type']?.toString() ?? '';
                return type.contains('audio') && type.contains('webm');
              }).toList();
              if (webmAudio.isNotEmpty) {
                webmAudio.sort((a, b) => ((b['bitrate'] as num?)?.toInt() ?? 0)
                    .compareTo((a['bitrate'] as num?)?.toInt() ?? 0));
                bestItag = webmAudio.first['itag'] as int?;
                _log.d('Invidious: itag WebM/Opus → $bestItag');
              }
            }
          }

          if (bestItag != null) {
            // URL correcta del proxy Invidious — el servidor sirve el audio directamente
            final proxyUrl =
                '$baseUrl/latest_version?id=$videoId&itag=$bestItag&local=true';
            print('URL FINAL DE AUDIO: $proxyUrl');
            _log.i('Invidious Proxy OK → $proxyUrl');
            return Right(proxyUrl);
          }
        }
      } catch (e) {
        lastError = e.toString();
        _log.w('Invidious $baseUrl falló: $e. Intentando siguiente...');
        continue; // Próxima instancia
      }
    }

    // Si ninguna instancia funcionó, usamos YoutubeExplode como último recurso
    _log.w('Todas las instancias Invidious fallaron: $lastError');

    // ── MOTOR 2: YoutubeExplode (Fallback Nativo con Reintentos) ─────────────
    _log.d('YoutubeExplode: Intentando extracción nativa para $videoId');

    // Intentar hasta 2 veces con YoutubeExplode con diferentes clientes
    for (int retry = 0; retry < 2; retry++) {
      try {
        bool isLiveStream = false;
        Duration? videoDuration;

        // Metadata fetch
        final video =
            await _yt.videos.get(videoId).timeout(const Duration(seconds: 12));
        isLiveStream = video.isLive;
        videoDuration = video.duration;

        if (isLiveStream ||
            videoDuration == null ||
            videoDuration == Duration.zero) {
          final nativeUrl = await _getHttpLiveStreamUrl(videoId);
          if (nativeUrl != null) return Right(nativeUrl);
          final hlsUrl = await _getLiveStreamUrl(videoId);
          if (hlsUrl != null) return Right(hlsUrl);
        } else {
          // Intentar estrategias de manifest
          for (final strategy in _getStrategies(isVideo)) {
            final result = await strategy(videoId);
            if (result != null) return Right(result);
          }
        }
      } catch (e) {
        _log.w('Retry $retry for $videoId failed: $e');
        // Pequeña espera antes del reintento
        await Future.delayed(Duration(milliseconds: 500 * (retry + 1)));
      }
    }

    // Fallback final: Piped API
    final pipedUrl = await _getPipedStreamUrl(videoId);
    if (pipedUrl != null) return Right(pipedUrl);

    return Left(StreamFailure(
      'No se pudo conectar con el motor de streaming tras varios intentos. Reintentando...',
      videoId: videoId,
    ));
  }

  Future<String?> _getHttpLiveStreamUrl(String videoId) async {
    try {
      _log.d('Trying getHttpLiveStreamUrl for: $videoId');
      final url = await _yt.videos.streamsClient
          .getHttpLiveStreamUrl(VideoId(videoId))
          .timeout(const Duration(seconds: 15));
      if (url.isNotEmpty) {
        _log.d('Got Native Live URL: ${url.substring(0, 50)}...');
        return url;
      }
    } catch (e) {
      _log.w('getHttpLiveStreamUrl failed: $e');
    }
    return null;
  }

  // ── MOTOR PIPED: API alternativa más estable ───────────────────────────────
  Future<String?> _getPipedStreamUrl(String videoId) async {
    // Piped instances list
    final pipedInstances = [
      'https://pipedapi.kavin.rocks',
      'https://api.piped.yt',
      'https://pipedapi.adminforge.de',
      'https://pipedapi.lunar.icu',
    ];

    for (final instance in pipedInstances) {
      try {
        _log.d('Piped: Intentando instancia $instance');

        // Get streams from Piped API
        final response = await http.get(
          Uri.parse('$instance/streams/$videoId'),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/122.0.0.0',
          },
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          // Find audio stream
          final audioStreams = data['audioStreams'] as List<dynamic>?;
          if (audioStreams != null && audioStreams.isNotEmpty) {
            // Get the best quality audio - find highest bitrate
            int maxBitrate = 0;
            Map<String, dynamic>? bestAudio;
            for (var stream in audioStreams) {
              final bitrate = (stream['bitrate'] as num?)?.toInt() ?? 0;
              if (bitrate > maxBitrate) {
                maxBitrate = bitrate;
                bestAudio = stream as Map<String, dynamic>;
              }
            }

            if (bestAudio != null) {
              final url = bestAudio['url'] as String?;
              if (url != null && url.isNotEmpty) {
                _log.d('Piped OK: $instance → audio');
                return url;
              }
            }
          }
        }
      } catch (e) {
        _log.w('Piped instance $instance failed: $e');
      }
    }
    return null;
  }

  Future<String?> _getLiveStreamUrl(String videoId) async {
    // Método Primario: getHttpLiveStreamUrl (Oficial para Live)
    try {
      _log.d('Primary Live Extraction for: $videoId');
      final url = await _yt.videos.streamsClient
          .getHttpLiveStreamUrl(VideoId(videoId))
          .timeout(const Duration(seconds: 20));

      if (url.isNotEmpty) {
        _log.d('Got Primary HLS URL');
        return url;
      }
    } catch (e) {
      _log.w('Primary extraction failed: $e');
    }

    // Método Secundario: Manifest con Clientes específicos
    final clients = [YoutubeApiClient.tv, YoutubeApiClient.ios];
    for (final client in clients) {
      try {
        _log.d('Secondary extraction with $client for: $videoId');
        final manifest = await _yt.videos.streamsClient.getManifest(videoId,
            ytClients: [client]).timeout(const Duration(seconds: 15));

        if (manifest.hls.isNotEmpty) {
          final url = manifest.hls.first.url.toString();
          if (url.isNotEmpty) return url;
        }
      } catch (e) {
        _log.w('Fallback $client failed: $e');
      }
    }
    return null;
  }

  List<Future<String?> Function(String)> _getStrategies(bool isVideo) {
    return [
      _tryTvClientFast,
      _tryAndroidVrFast,
      _tryIosClient,
      _tryAndroidClient,
      _tryAnyAudio,
    ];
  }

  // estrategias rápidas (8s timeout, en paralelo)
  Future<String?> _tryTvClientFast(String videoId) async {
    try {
      _log.d('Strategy: TV for $videoId');
      final manifest = await _yt.videos.streamsClient.getManifest(videoId,
          ytClients: [YoutubeApiClient.tv]).timeout(const Duration(seconds: 8));

      final stream = manifest.audioOnly.withHighestBitrate();
      return stream.url.toString();
    } catch (e) {
      _log.w('TV failed: $e');
    }
    return null;
  }

  Future<String?> _tryAndroidVrFast(String videoId) async {
    try {
      _log.d('Strategy: Android VR for $videoId');
      final manifest = await _yt.videos.streamsClient.getManifest(videoId,
          ytClients: [
            YoutubeApiClient.androidVr
          ]).timeout(const Duration(seconds: 8));

      final stream = manifest.audioOnly.withHighestBitrate();
      return stream.url.toString();
    } catch (e) {
      _log.w('AndroidVR failed: $e');
    }
    return null;
  }

  Future<String?> _tryTvClient(String videoId) async {
    try {
      _log.d('Strategy: TV for $videoId');
      final manifest = await _yt.videos.streamsClient.getManifest(videoId,
          ytClients: [YoutubeApiClient.tv]).timeout(const Duration(seconds: 8));

      final stream = manifest.audioOnly.withHighestBitrate();
      return stream.url.toString();
    } catch (e) {
      _log.w('TV strategy failed: $e');
    }
    return null;
  }



  /// Estrategia: Cliente iOS
  Future<String?> _tryIosClient(String videoId) async {
    try {
      _log.d('Strategy: iOS client for $videoId');
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId, ytClients: [YoutubeApiClient.ios]).timeout(
              const Duration(seconds: 15));

      final stream = manifest.audioOnly.withHighestBitrate();
      return stream.url.toString();
    } catch (e) {
      _log.w('iOS strategy failed: $e');
    }
    return null;
  }

  /// Estrategia 2: Cliente Android genérico (sin VR) — evita el throttle del cliente androidVr
  Future<String?> _tryAndroidClient(String videoId) async {
    try {
      _log.d('Estrategia Android para $videoId');
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId, ytClients: [YoutubeApiClient.android]).timeout(
              const Duration(seconds: 15));

      final stream = manifest.audioOnly
              .where((s) => s.container.name == 'm4a')
              .sortByBitrate()
              .lastOrNull ??
          manifest.audioOnly.sortByBitrate().lastOrNull;

      if (stream != null) {
        _log.d(
            'Estrategia Android OK: ${stream.container.name} ${stream.bitrate}');
        return stream.url.toString();
      }
    } catch (e) {
      _log.w('Estrategia Android falló: $e');
    }
    return null;
  }

  /// Estrategia: Android VR (altamente estable para streams de audio)
  Future<String?> _tryAndroidVrClient(String videoId) async {
    try {
      _log.d('Strategy: Android VR for $videoId');
      final manifest = await _yt.videos.streamsClient.getManifest(videoId,
          ytClients: [
            YoutubeApiClient.androidVr
          ]).timeout(const Duration(seconds: 15));

      final stream = manifest.audioOnly.withHighestBitrate();
      return stream.url.toString();
    } catch (e) {
      _log.w('Android VR strategy failed: $e');
    }
    return null;
  }

  /// Estrategia 3: Cualquier audio disponible (último recurso)
  Future<String?> _tryAnyAudio(String videoId) async {
    try {
      _log.d('Estrategia 3 (any audio) para $videoId');
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId, ytClients: [YoutubeApiClient.ios]).timeout(
              const Duration(seconds: 15));

      if (manifest.audioOnly.isNotEmpty) {
        final stream = manifest.audioOnly.first;
        _log.d('Estrategia 3 OK: ${stream.container.name} ${stream.bitrate}');
        return stream.url.toString();
      }
    } catch (e) {
      _log.w('Estrategia 3 falló: $e');
    }
    return null;
  }

  // ── Playlist ──────────────────────────────────────────────────────────────

  @override
  FutureEither<PlaylistEntity> getPlaylist(String playlistId) async {
    try {
      String actualPlaylistId = playlistId;
      String? seedVideoId;

      if (playlistId.contains('|')) {
        final parts = playlistId.split('|');
        actualPlaylistId = parts[0];
        seedVideoId = parts[1];
      }

      Playlist? playlist;
      try {
        playlist = await _yt.playlists
            .get(actualPlaylistId)
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        _log.w('Could not fetch playlist metadata for $actualPlaylistId: $e');
      }

      List<Video> videos = [];
      try {
        videos = await _yt.playlists
            .getVideos(actualPlaylistId)
            .take(100)
            .toList()
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        _log.w('Could not fetch playlist videos for $actualPlaylistId: $e');
      }

      List<SongEntity> songs = _mapToSongList(videos);

      // Fallback for YouTube Mixes (IDs starting with RD)
      if (songs.isEmpty && actualPlaylistId.startsWith('RD')) {
        _log.i(
            'Detected possible Mix ID $actualPlaylistId with 0 tracks. Attempting fallback.');

        // Use the last 11 characters as the seed video ID (standard for RD mixes)
        seedVideoId ??= actualPlaylistId.length >= 13
            ? actualPlaylistId.substring(actualPlaylistId.length - 11)
            : null;

        if (seedVideoId != null && _isValidVideoId(seedVideoId)) {
          _log.d('Trying to get content for seed video $seedVideoId');
          try {
            // Include the seed video itself first
            final seedVideo = await _yt.videos
                .get(seedVideoId!)
                .timeout(const Duration(seconds: 10));

            // Get related videos - using fetchExtended to get up to 60 tracks (good balance for home/import)
            final related = await _yt.videos.getRelatedVideos(seedVideo);
            final List<dynamic> extendedList =
                await _fetchExtended(related, 60);

            final List<dynamic> rawList = [seedVideo, ...extendedList];
            songs = _mapToSongList(rawList);
          } catch (e) {
            _log.w('Fallback for mix failed: $e');
          }
        }
      }

      if (songs.isEmpty && playlist == null) {
        return const Left(YoutubeFailure(
            'No se pudieron encontrar temas en esta lista. Verificá que sea pública.'));
      }

      // If we have no playlist object (common for RD mixes), create a descriptive entity
      String title = playlist?.title ??
          (actualPlaylistId.startsWith('RD')
              ? 'Mix de YouTube'
              : 'Lista Importada');

      // If it's a mix and we have songs, try to make the title better
      if (actualPlaylistId.startsWith('RD') &&
          songs.isNotEmpty &&
          playlist == null) {
        title =
            'Mix: ${songs.first.artist}'; // Usually mixes are based on an artist/song
      }

      final entity = playlist?.toEntity(tracks: songs) ??
          PlaylistEntity(
            id: actualPlaylistId,
            title: title,
            tracks: songs,
            trackCount: songs.length,
            thumbnailUrl: songs.isNotEmpty ? songs.first.bestThumbnail : null,
          );

      return Right(entity);
    } catch (e) {
      _log.e('Playlist fetch failed: $playlistId', error: e);
      return const Left(
          YoutubeFailure('No se pudo cargar la lista. Reintenta más tarde.'));
    }
  }

  // ── Recommendations ───────────────────────────────────────────────────────

  @override
  FutureEither<List<SongEntity>> getRecommendations() async {
    try {
      _log.d('Fetching recommendations via Dynamic Engine...');
      // Usamos el método search que ya está ruteado por Invidious/FlowyEngine
      final result = await search('top global hits 2026');

      return result.fold(
        (failure) => Left(failure),
        (searchResult) {
          if (searchResult.songs.isEmpty) {
            return Left(YoutubeFailure('No se encontraron recomendaciones.'));
          }
          return Right(searchResult.songs);
        },
      );
    } catch (e) {
      _log.e('Recommendations failed: $e');
      return Left(YoutubeFailure('Could not load recommendations'));
    }
  }

  /// Helper to fetch multiple pages from a SearchList until reaching target count
  Future<List<dynamic>> _fetchExtended(dynamic initial, int target) async {
    if (initial == null) return [];

    final List<dynamic> all = List<dynamic>.from(initial as Iterable);
    dynamic current = initial;

    // We limit safety to 6 pages max to avoid excessive API calls
    for (int page = 1; page < 6 && all.length < target; page++) {
      try {
        final next =
            await current.nextPage().timeout(const Duration(seconds: 5));
        if (next == null || next.isEmpty) break;

        all.addAll(List<dynamic>.from(next as Iterable));
        current = next;
      } catch (_) {
        break;
      }
    }
    return all;
  }

  // ── Lyrics ────────────────────────────────────────────────────────────────

  @override
  FutureEither<LyricsEntity> getLyrics(
      String videoId, String title, String artist) async {
    return _lyricsSource.getLyrics(videoId, title, artist);
  }

  // ── Charts ────────────────────────────────────────────────────────────────

  @override
  FutureEither<List<PlaylistEntity>> getCharts() async {
    // YouTube Music chart playlists (well-known IDs)
    const chartIds = [
      'PLFgquLnL59akA2PflFpeQG9L01VFg90wS', // Global Top 100
      'PLFgquLnL59alGJcdc5-mnCr3R9E4gHNv4', // US Charts
    ];

    try {
      final futures = chartIds.map((id) => _yt.playlists.get(id));
      final playlists = await Future.wait(futures);
      return Right(playlists.map((p) => p.toEntity()).toList());
    } catch (e) {
      return Left(YoutubeFailure('Charts unavailable'));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> getVideoDetails(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId);
      return Right({
        'id': video.id.value,
        'title': video.title,
        'description': video.description,
        'author': video.author,
        'duration': video.duration,
      });
    } catch (e) {
      return Left(YoutubeFailure('Could not fetch video details'));
    }
  }

  List<SongEntity> _mapToSongList(List<dynamic> videos) {
    return videos
        .map((v) {
          if (v is SearchVideo) return v.toSongEntity();
          if (v is Video) return v.toSongEntity();
          // Safe dynamic fallback
          try {
            return (v as dynamic).toSongEntity() as SongEntity;
          } catch (_) {}
          return null;
        })
        .whereType<SongEntity>()
        .where((s) => _isValidVideoId(s.id))
        .toList();
  }
}
