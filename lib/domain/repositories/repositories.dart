import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/entities.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Domain Repository Contracts
// Pure abstract interfaces — implementations live in the Data layer
// ─────────────────────────────────────────────────────────────────────────────

abstract class MusicRepository {
  /// Search YouTube Music for [query], returning typed results.
  FutureEither<SearchResultEntity> search(String query);

  /// Fetch autocomplete suggestions for partial [query].
  FutureEither<List<String>> getSearchSuggestions(String query);

  /// Resolve the audio stream URL for [videoId].
  /// Attempts mirror fallback if primary extraction fails.
  FutureEither<String> getStreamUrl(String videoId);

  /// Fetch full playlist details including all tracks.
  FutureEither<PlaylistEntity> getPlaylist(String playlistId);

  /// Returns a list of trending / recommended songs for the home screen.
  FutureEither<List<SongEntity>> getRecommendations();

  /// Fetch lyrics for [videoId]. Returns synced lyrics when available.
  FutureEither<LyricsEntity> getLyrics(String videoId, String title,
      String artist);

  /// Fetch chart playlists (Global Top, Country, etc.)
  FutureEither<List<PlaylistEntity>> getCharts();

  /// NEW: Fetch full video details including description (for chapters).
  FutureEither<Map<String, dynamic>> getVideoDetails(String videoId);
}

abstract class LocalLibraryRepository {
  /// Add [song] to the liked songs collection.
  FutureEither<void> likeSong(SongEntity song);

  /// Remove [songId] from liked songs.
  FutureEither<void> unlikeSong(String songId);

  /// Returns true if [songId] is in the liked songs collection.
  Future<bool> isLiked(String songId);

  /// Returns all liked songs, latest first.
  Future<List<SongEntity>> getLikedSongs();

  /// Saves [history] entry.
  FutureEither<void> addToHistory(SongEntity song);

  /// Returns play history, most recent first.
  Future<List<SongEntity>> getHistory();

  /// Create a new playlist with [name].
  FutureEither<PlaylistEntity> createPlaylist(String name);

  /// Add [song] to [playlistId].
  FutureEither<void> addToPlaylist(String playlistId, SongEntity song);

  /// Returns all user-created playlists.
  Future<List<PlaylistEntity>> getUserPlaylists();

  /// NEW: Manage playback bookmarks (Listening Memory)
  Future<void> saveBookmark(String songId, int seconds);
  Future<int?> getBookmark(String songId);
}
