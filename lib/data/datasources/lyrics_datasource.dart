import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/entities.dart';
import '../models/song_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LyricsDataSource — fetches synced/plain lyrics from open APIs
// Uses lrclib.net (free, no key required) with plain text fallback
// ─────────────────────────────────────────────────────────────────────────────

class LyricsDataSource {
  static const String _lrclibBase = 'https://lrclib.net/api';
  final http.Client _client;

  LyricsDataSource({http.Client? client}) : _client = client ?? http.Client();

  String _cleanTitle(String title) {
    return title.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]|(?i)official|(?i)video|(?i)audio|(?i)lyric|(?i)music'), '').trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<Either<Failure, LyricsEntity>> getLyrics(
      String songId, String rawTitle, String artist) async {
    final title = _cleanTitle(rawTitle);
    try {
      // Attempt 1: synced lyrics (LRC format)
      final syncedResult =
          await _fetchSyncedLyrics(songId, title, artist);
      if (syncedResult != null) return Right(syncedResult);

      // Attempt 2: plain lyrics
      final plainResult = await _fetchPlainLyrics(songId, title, artist);
      if (plainResult != null) return Right(plainResult);

      return Left(CacheFailure('Lyrics not found for "$title"'));
    } catch (e) {
      return Left(NetworkFailure('Could not fetch lyrics'));
    }
  }

  Future<LyricsEntity?> _fetchSyncedLyrics(
      String songId, String title, String artist) async {
    final uri = Uri.parse('$_lrclibBase/search').replace(queryParameters: {
      'track_name': title,
      'artist_name': artist,
    });

    final response = await _client
        .get(uri, headers: {'User-Agent': 'Flowy/1.0'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return null;

    final List<dynamic> json = jsonDecode(response.body);
    for (final item in json) {
      final lrc = item['syncedLyrics'] as String?;
      if (lrc != null && lrc.isNotEmpty) {
        return LyricsModel.fromLrc(songId, lrc).toEntity();
      }
    }
    return null;
  }

  Future<LyricsEntity?> _fetchPlainLyrics(
      String songId, String title, String artist) async {
    final uri = Uri.parse('$_lrclibBase/search').replace(queryParameters: {
      'track_name': title,
      'artist_name': artist,
    });

    final response = await _client
        .get(uri, headers: {'User-Agent': 'Flowy/1.0'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return null;

    final List<dynamic> json = jsonDecode(response.body);
    for (final item in json) {
      final plain = item['plainLyrics'] as String?;
      if (plain != null && plain.isNotEmpty) {
        final lines = plain.split('\n').map((line) {
          return LyricLineEntity(
            timestamp: Duration.zero,
            text: line,
          );
        }).toList();
        return LyricsEntity(songId: songId, lines: lines, isSynced: false);
      }
    }
    return null;
  }
}
