import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../domain/entities/entities.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data Models — map between YouTube Explode DTOs and domain entities
// v2.5.x compatible
// ─────────────────────────────────────────────────────────────────────────────

extension VideoToSongEntity on Video {
  SongEntity toSongEntity() {
    return SongEntity(
      id: id.value,
      title: title,
      artist: author,
      thumbnailUrl: thumbnails.mediumResUrl,
      highResThumbnailUrl: thumbnails.maxResUrl,
      duration: duration ?? Duration.zero,
    );
  }
}

extension SearchVideoToSongEntity on SearchVideo {
  SongEntity toSongEntity() {
    final thumbHigh =
        thumbnails.isNotEmpty ? thumbnails.last.url.toString() : '';
    final thumbLow =
        thumbnails.isNotEmpty ? thumbnails.first.url.toString() : '';

    // SearchVideo.duration is a String like "3:45" in v2.x
    final parsedDuration = _parseDurationString(duration);

    return SongEntity(
      id: id.value,
      title: title,
      artist: author,
      thumbnailUrl: thumbLow,
      highResThumbnailUrl: thumbHigh,
      duration: parsedDuration,
    );
  }

  Duration _parseDurationString(String dur) {
    try {
      final parts = dur.split(':').map(int.parse).toList();
      if (parts.length == 3) {
        return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
      } else if (parts.length == 2) {
        return Duration(minutes: parts[0], seconds: parts[1]);
      }
    } catch (_) {}
    return Duration.zero;
  }
}

extension PlaylistToEntity on Playlist {
  PlaylistEntity toEntity({List<SongEntity>? tracks}) {
    // In v2.5.x, Playlist.author is a String
    // ThumbnailSet supports .mediumResUrl etc.
    return PlaylistEntity(
      id: id.value,
      title: title,
      description: description,
      thumbnailUrl: thumbnails.mediumResUrl,
      // author is already a String in v2.5.x
      author: author,
      trackCount: videoCount,
      tracks: tracks ?? [],
    );
  }
}

class SongModel {
  final String id;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final String? highResThumbnailUrl;
  final Duration duration;
  final bool isVideo;

  SongModel({
    required this.id,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.highResThumbnailUrl,
    this.duration = Duration.zero,
    this.isVideo = false,
  });

  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      highResThumbnailUrl: json['highResThumbnailUrl'] as String?,
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      isVideo: json['isVideo'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'thumbnailUrl': thumbnailUrl,
      'highResThumbnailUrl': highResThumbnailUrl,
      'durationMs': duration.inMilliseconds,
      'isVideo': isVideo,
    };
  }

  factory SongModel.fromEntity(SongEntity entity) {
    return SongModel(
      id: entity.id,
      title: entity.title,
      artist: entity.artist,
      thumbnailUrl: entity.thumbnailUrl,
      highResThumbnailUrl: entity.highResThumbnailUrl,
      duration: entity.duration,
      isVideo: entity.isVideo,
    );
  }

  SongEntity toSongEntity() {
    return SongEntity(
      id: id,
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
      highResThumbnailUrl: highResThumbnailUrl,
      duration: duration,
      isVideo: isVideo,
    );
  }
}

class LyricsModel {
  final String songId;
  final List<LyricLineModel> lines;
  final bool isSynced;

  const LyricsModel({
    required this.songId,
    required this.lines,
    this.isSynced = false,
  });

  LyricsEntity toEntity() {
    return LyricsEntity(
      songId: songId,
      lines: lines.map((l) => l.toEntity()).toList(),
      isSynced: isSynced,
    );
  }

  /// Parse LRC format lyrics.
  static LyricsModel fromLrc(String songId, String lrcContent) {
    final lines = <LyricLineModel>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (final line in lrcContent.split('\n')) {
      final match = regex.firstMatch(line.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final centis = int.parse(match.group(3)!.padRight(3, '0'));
        final text = match.group(4)?.trim() ?? '';

        lines.add(LyricLineModel(
          timestamp: Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: centis,
          ),
          text: text,
        ));
      }
    }

    return LyricsModel(
      songId: songId,
      lines: lines,
      isSynced: lines.isNotEmpty,
    );
  }
}

class LyricLineModel {
  final Duration timestamp;
  final String text;

  const LyricLineModel({required this.timestamp, required this.text});

  LyricLineEntity toEntity() =>
      LyricLineEntity(timestamp: timestamp, text: text);
}
