import 'package:sqflite/sqflite.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../models/song_model.dart';
import '../../core/database/app_database.dart';
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';

class LocalLibraryRepositoryImpl implements LocalLibraryRepository {
  final AppDatabase _db = AppDatabase();

  @override
  FutureEither<void> likeSong(SongEntity song) async {
    try {
      final database = await _db.database;
      await database.insert(
        'liked_songs',
        {
          'id': song.id,
          'title': song.title,
          'artist': song.artist,
          'thumbnailUrl': song.thumbnailUrl,
          'highResThumbnailUrl': song.highResThumbnailUrl,
          'durationMs': song.duration.inMilliseconds,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Liked songs update failed: $e'));
    }
  }

  @override
  FutureEither<void> unlikeSong(String songId) async {
    try {
      final database = await _db.database;
      await database.delete('liked_songs', where: 'id = ?', whereArgs: [songId]);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Liked songs delete failed: $e'));
    }
  }

  @override
  Future<bool> isLiked(String songId) async {
    final database = await _db.database;
    final results = await database.query('liked_songs', where: 'id = ?', whereArgs: [songId]);
    return results.isNotEmpty;
  }

  @override
  Future<List<SongEntity>> getLikedSongs() async {
    final database = await _db.database;
    final results = await database.query('liked_songs', orderBy: 'addedAt DESC');
    return results.map((r) => _mapToSong(r)).toList();
  }

  @override
  FutureEither<void> addToHistory(SongEntity song) async {
    try {
      final database = await _db.database;
      
      // Update play count or insert
      await database.execute('''
        INSERT INTO history (id, title, artist, thumbnailUrl, highResThumbnailUrl, durationMs, lastPlayedAt, playCount)
        VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, 1)
        ON CONFLICT(id) DO UPDATE SET 
          lastPlayedAt = CURRENT_TIMESTAMP,
          playCount = playCount + 1
      ''', [song.id, song.title, song.artist, song.thumbnailUrl, song.highResThumbnailUrl, song.duration.inMilliseconds]);
      
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('History update failed: $e'));
    }
  }

  @override
  Future<List<SongEntity>> getHistory() async {
    final database = await _db.database;
    final results = await database.query('history', orderBy: 'lastPlayedAt DESC', limit: 100);
    return results.map((r) => _mapToSong(r)).toList();
  }

  // --- Bookmark Logic ---
  
  Future<void> saveBookmark(String songId, int seconds) async {
    final database = await _db.database;
    await database.insert(
      'bookmarks',
      {'songId': songId, 'positionSeconds': seconds, 'updatedAt': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int?> getBookmark(String songId) async {
    final database = await _db.database;
    final results = await database.query('bookmarks', where: 'songId = ?', whereArgs: [songId]);
    if (results.isEmpty) return null;
    return results.first['positionSeconds'] as int?;
  }

  // Unsupported for now
  @override
  FutureEither<PlaylistEntity> createPlaylist(String name) async => Left(UnknownFailure('Not implemented', null));
  @override
  FutureEither<void> addToPlaylist(String pid, SongEntity s) async => Left(UnknownFailure('Not implemented', null));
  @override
  Future<List<PlaylistEntity>> getUserPlaylists() async => [];

  SongEntity _mapToSong(Map<String, dynamic> r) {
    return SongEntity(
      id: r['id'] as String,
      title: r['title'] as String,
      artist: r['artist'] as String,
      thumbnailUrl: r['thumbnailUrl'] as String?,
      highResThumbnailUrl: r['highResThumbnailUrl'] as String?,
      duration: Duration(milliseconds: r['durationMs'] as int? ?? 0),
    );
  }
}
