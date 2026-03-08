import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../core/errors/failures.dart';
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
      final results = await _yt.search.search(query).timeout(const Duration(seconds: 10));
      final songs = results
          .map((v) => v.toSongEntity())
          .where((s) => _isValidVideoId(s.id)) // ENFORCE VALID IDS
          .toList();

      return Right(SearchResultEntity(query: query, songs: songs));
    } on TimeoutException {
      _log.e('YouTube search timed out for $query');
      return Left(YoutubeFailure('Search timed out. Check your connection.'));
    } on YoutubeExplodeException catch (e) {
      _log.e('YouTube search failed', error: e);
      return Left(YoutubeFailure('Search failed: ${e.message}'));
    } catch (e) {
      _log.e('Unknown search error', error: e);
      return Left(UnknownFailure('Search error', e));
    }
  }

  // ── Suggestions ───────────────────────────────────────────────────────────

  @override
  FutureEither<List<String>> getSearchSuggestions(String query) async {
    try {
      final results = await _yt.search.getQuerySuggestions(query).timeout(const Duration(seconds: 5));
      return Right(results);
    } catch (e) {
      return Left(YoutubeFailure('Suggestions failed'));
    }
  }

  // ── Stream URL ────────────────────────────────────────────────────────────

  @override
  FutureEither<String> getStreamUrl(String videoId) async {
    if (!_isValidVideoId(videoId)) {
      _log.e('Invalid YouTube video ID: $videoId');
      return Left(YoutubeFailure('Invalid video ID format'));
    }

    if (_streamCache.containsKey(videoId)) {
      _log.d('Stream URL from cache for $videoId');
      return Right(_streamCache[videoId]!);
    }

    // Intentar con múltiples estrategias de extracción
    for (final strategy in _extractionStrategies) {
      final result = await strategy(videoId);
      if (result != null) {
        _streamCache[videoId] = result;
        return Right(result);
      }
    }

    return Left(StreamFailure(
      'No se pudo obtener URL de stream. La pista puede ser restringida.',
      videoId: videoId,
    ));
  }

  /// Lista de estrategias de extracción en orden de preferencia
  late final List<Future<String?> Function(String)> _extractionStrategies = [
    _tryAndroidClient,
    _tryDefaultClient,
    _tryAnyAudio,
  ];

  /// Estrategia 1: Cliente Android — genera URLs directamente reproducibles por ExoPlayer
  Future<String?> _tryAndroidClient(String videoId) async {
    try {
      _log.d('Estrategia 1 (Android client) para $videoId');
      // Usar YoutubeExplode con HttpClient personalizado que simula Android
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId, ytClients: [YoutubeApiClient.androidVr])
          .timeout(const Duration(seconds: 12));

      final stream = manifest.audioOnly
              .where((s) => s.container.name == 'm4a')
              .sortByBitrate()
              .lastOrNull ?? // lastOrNull = menor bitrate = más estable en móvil
          manifest.audioOnly.sortByBitrate().lastOrNull;

      if (stream != null) {
        _log.d('Estrategia 1 OK: ${stream.container.name} ${stream.bitrate}');
        return stream.url.toString();
      }
    } catch (e) {
      _log.w('Estrategia 1 falló: $e');
    }
    return null;
  }

  /// Estrategia 2: Cliente por defecto
  Future<String?> _tryDefaultClient(String videoId) async {
    try {
      _log.d('Estrategia 2 (cliente default) para $videoId');
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 12));

      final stream = manifest.audioOnly
              .where((s) => s.container.name == 'm4a')
              .sortByBitrate()
              .lastOrNull ??
          manifest.audioOnly.withHighestBitrate();

      _log.d('Estrategia 2 OK: ${stream.container.name} ${stream.bitrate}');
      return stream.url.toString();
    } catch (e) {
      _log.w('Estrategia 2 falló: $e');
    }
    return null;
  }

  /// Estrategia 3: Cualquier audio disponible (último recurso)
  Future<String?> _tryAnyAudio(String videoId) async {
    try {
      _log.d('Estrategia 3 (any audio) para $videoId');
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId, ytClients: [YoutubeApiClient.ios])
          .timeout(const Duration(seconds: 15));

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
      final playlistFuture = _yt.playlists.get(playlistId);
      final videosFuture =
          _yt.playlists.getVideos(playlistId).take(100).toList();

      final results = await Future.wait([playlistFuture, videosFuture]);
      final playlist = results[0] as Playlist;
      final videos = results[1] as List;

      final songs =
          videos.cast<Video>()
          .map((v) => v.toSongEntity())
          .where((s) => _isValidVideoId(s.id)) // ENFORCE VALID IDS
          .toList();

      return Right(playlist.toEntity(tracks: songs));
    } catch (e) {
      _log.e('Playlist fetch failed: $playlistId', error: e);
      return Left(YoutubeFailure('Playlist unavailable'));
    }
  }

  // ── Recommendations ───────────────────────────────────────────────────────

  @override
  FutureEither<List<SongEntity>> getRecommendations() async {
    try {
      // Buscar música tendencia global como proxy para recomendaciones
      final results = await _yt.search
          .search('top hits 2024 music', filter: TypeFilters.video);
      final songs = results
          .take(20)
          .map((v) => v.toSongEntity())
          .where((s) => _isValidVideoId(s.id)) // ENFORCE VALID IDS
          .toList();
      return Right(songs);
    } catch (e) {
      return Left(YoutubeFailure('Could not load recommendations'));
    }
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
}
