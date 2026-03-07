import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Core Domain Entities
// Pure Dart classes — no framework dependencies whatsoever
// ─────────────────────────────────────────────────────────────────────────────

class SongEntity extends Equatable {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? albumId;
  final String? thumbnailUrl;
  final String? highResThumbnailUrl;
  final Duration duration;
  final String? streamUrl;
  final bool isLocal;
  final Map<String, dynamic>? extras;

  const SongEntity({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.albumId,
    this.thumbnailUrl,
    this.highResThumbnailUrl,
    this.duration = Duration.zero,
    this.streamUrl,
    this.isLocal = false,
    this.extras,
  });

  String get displayDuration {
    final m = duration.inMinutes;
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get bestThumbnail =>
      highResThumbnailUrl ?? thumbnailUrl ?? '';

  SongEntity copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? albumId,
    String? thumbnailUrl,
    String? highResThumbnailUrl,
    Duration? duration,
    String? streamUrl,
    bool? isLocal,
    Map<String, dynamic>? extras,
  }) {
    return SongEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      highResThumbnailUrl: highResThumbnailUrl ?? this.highResThumbnailUrl,
      duration: duration ?? this.duration,
      streamUrl: streamUrl ?? this.streamUrl,
      isLocal: isLocal ?? this.isLocal,
      extras: extras ?? this.extras,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        artist,
        album,
        thumbnailUrl,
        duration,
        streamUrl,
      ];
}

// ─────────────────────────────────────────────────────────────────────────────

class PlaylistEntity extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String? author;
  final int? trackCount;
  final List<SongEntity> tracks;

  const PlaylistEntity({
    required this.id,
    required this.title,
    this.description,
    this.thumbnailUrl,
    this.author,
    this.trackCount,
    this.tracks = const [],
  });

  @override
  List<Object?> get props => [id, title, author, trackCount];
}

// ─────────────────────────────────────────────────────────────────────────────

class ArtistEntity extends Equatable {
  final String id;
  final String name;
  final String? thumbnailUrl;
  final String? description;
  final int? subscriberCount;

  const ArtistEntity({
    required this.id,
    required this.name,
    this.thumbnailUrl,
    this.description,
    this.subscriberCount,
  });

  @override
  List<Object?> get props => [id, name];
}

// ─────────────────────────────────────────────────────────────────────────────

class SearchResultEntity extends Equatable {
  final List<SongEntity> songs;
  final List<PlaylistEntity> playlists;
  final List<ArtistEntity> artists;
  final String query;

  const SearchResultEntity({
    required this.query,
    this.songs = const [],
    this.playlists = const [],
    this.artists = const [],
  });

  bool get isEmpty => songs.isEmpty && playlists.isEmpty && artists.isEmpty;

  @override
  List<Object?> get props => [query, songs, playlists, artists];
}

// ─────────────────────────────────────────────────────────────────────────────

class LyricLineEntity extends Equatable {
  final Duration timestamp;
  final String text;

  const LyricLineEntity({required this.timestamp, required this.text});

  @override
  List<Object?> get props => [timestamp, text];
}

class LyricsEntity extends Equatable {
  final String songId;
  final List<LyricLineEntity> lines;
  final bool isSynced;

  const LyricsEntity({
    required this.songId,
    required this.lines,
    this.isSynced = false,
  });

  bool get isEmpty => lines.isEmpty;

  @override
  List<Object?> get props => [songId, lines, isSynced];
}
