import '../../domain/entities/entities.dart';
import 'song_model.dart';

class UserPlaylistModel {
  final String id;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final List<SongModel> tracks;
  final bool isFolder;
  final List<UserPlaylistModel> subPlaylists;

  UserPlaylistModel({
    required this.id,
    required this.title,
    this.description,
    this.thumbnailUrl,
    required this.tracks,
    this.isFolder = false,
    this.subPlaylists = const [],
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
      isFolder: json['isFolder'] as bool? ?? false,
      subPlaylists: (json['subPlaylists'] as List<dynamic>? ?? [])
          .map((e) => UserPlaylistModel.fromJson(e as Map<String, dynamic>))
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
      'isFolder': isFolder,
      'subPlaylists': subPlaylists.map((e) => e.toJson()).toList(),
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
      isFolder: isFolder,
      subPlaylists: subPlaylists.map((e) => e.toEntity()).toList(),
    );
  }

  factory UserPlaylistModel.fromEntity(PlaylistEntity entity) {
    return UserPlaylistModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      thumbnailUrl: entity.thumbnailUrl,
      tracks: entity.tracks.map((e) => SongModel.fromEntity(e)).toList(),
      isFolder: entity.isFolder,
      subPlaylists: entity.subPlaylists.map((e) => UserPlaylistModel.fromEntity(e)).toList(),
    );
  }
}
