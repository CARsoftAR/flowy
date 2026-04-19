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
      isLive: isLive,
      isVideo: true,
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
      isVideo: true,
    );
  }

  Duration _parseDurationString(String dur) {
    try {
      final cleanDur = dur.replaceFirst('-', ''); // Handle negative strings
      final parts = cleanDur.split(':').map(int.parse).toList();
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
    for (final line in lrcContent.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Matches [mm:ss.xx] or [mm:ss.xxx] or [mm:ss] or [m:ss.x]
      final regex = RegExp(r'\[(\d+):(\d{2})(?:[\.:](\d+))?\](.*)');
      final match = regex.firstMatch(trimmed);
      
      if (match != null) {
        final m = int.parse(match.group(1)!);
        final s = int.parse(match.group(2)!);
        final msStr = match.group(3) ?? '0';
        final text = match.group(4)?.trim() ?? '';

        // Handle milliseconds/centiseconds intelligently (e.g. .5 -> 500, .50 -> 500, .05 -> 050)
        int ms = 0;
        if (msStr.length == 1) ms = int.parse(msStr) * 100;
        if (msStr.length == 2) ms = int.parse(msStr) * 10;
        if (msStr.length >= 3) ms = int.parse(msStr.substring(0, 3));

        lines.add(LyricLineModel(
          timestamp: Duration(minutes: m, seconds: s, milliseconds: ms),
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
