import '../../domain/entities/entities.dart';
import 'song_model.dart';

class UserPlaylistModel {
  final String id;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final List<SongModel> tracks;

  UserPlaylistModel({
    required this.id,
    required this.title,
    this.description,
    this.thumbnailUrl,
    required this.tracks,
  });

  factory UserPlaylistModel.fromJson(Map<String, dynamic> json) {
    return UserPlaylistModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      tracks: (json['tracks'] as List<dynamic>? ?? [])
          .map((e) => SongModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'tracks': tracks.map((e) => e.toJson()).toList(),
    };
  }

  PlaylistEntity toEntity() {
    return PlaylistEntity(
      id: id,
      title: title,
      description: description,
      thumbnailUrl: thumbnailUrl,
      tracks: tracks.map((e) => e.toSongEntity()).toList(),
      trackCount: tracks.length,
    );
  }

  factory UserPlaylistModel.fromEntity(PlaylistEntity entity) {
    return UserPlaylistModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      thumbnailUrl: entity.thumbnailUrl,
      tracks: entity.tracks.map((e) => SongModel.fromEntity(e)).toList(),
    );
  }
}
