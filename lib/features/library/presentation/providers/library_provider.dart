import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../data/models/song_model.dart';

import '../../../../data/models/playlist_model.dart';
import 'package:uuid/uuid.dart';

class LibraryProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  
  List<SongEntity> _likedSongs = [];
  List<SongEntity> _recentlyPlayed = [];
  List<PlaylistEntity> _playlists = [];
  
  static const String _likedKey = 'liked_songs';
  static const String _recentKey = 'recent_played';
  static const String _playlistsKey = 'user_playlists';
  static const String _countsKey = 'play_counts';
  static const int _maxRecent = 100;

  Map<String, int> _playCounts = {};
  Map<String, SongEntity> _idToSong = {};

  LibraryProvider(this._prefs) {
    refreshData();
  }

  List<SongEntity> get likedSongs => _likedSongs;
  List<SongEntity> get recentlyPlayed => _recentlyPlayed;
  List<PlaylistEntity> get playlists => _playlists;

  SongEntity? getSong(String id) => _idToSong[id];
  int getPlayCount(String id) => _playCounts[id] ?? 0;

  double getBookmarkProgress(String songId, Duration totalDuration) {
    return 0.0;
  }

  void refreshData() {
    final likedJson = _prefs.getStringList(_likedKey) ?? [];
    _likedSongs = likedJson.map((j) {
        final s = SongModel.fromJson(jsonDecode(j)).toSongEntity();
        _idToSong[s.id] = s;
        return s;
    }).toList();

    final recentJson = _prefs.getStringList(_recentKey) ?? [];
    _recentlyPlayed = recentJson.map((j) {
        final s = SongModel.fromJson(jsonDecode(j)).toSongEntity();
        _idToSong[s.id] = s;
        return s;
    }).toList();

    final playlistsJson = _prefs.getStringList(_playlistsKey) ?? [];
    _playlists = playlistsJson.map((j) {
        return UserPlaylistModel.fromJson(jsonDecode(j)).toEntity();
    }).toList();
    
    final countsJson = _prefs.getString(_countsKey);
    if (countsJson != null) {
      _playCounts = Map<String, int>.from(jsonDecode(countsJson));
    }
    
    notifyListeners();
  }

  // --- Playlist Management ---

  Future<String> createPlaylist(String title, {String? description, String? parentFolderId}) async {
    final id = const Uuid().v4();
    final playlist = PlaylistEntity(
      id: id,
      title: title,
      description: description,
      tracks: const [],
    );
    
    if (parentFolderId == null) {
      _playlists.add(playlist);
    } else {
      _addItemToFolder(_playlists, parentFolderId, playlist);
    }
    await _savePlaylists();
    return id;
  }

  Future<String> createFolder(String title, {String? parentFolderId}) async {
    final id = const Uuid().v4();
    final folder = PlaylistEntity(
      id: id,
      title: title,
      isFolder: true,
      subPlaylists: const [],
    );
    
    if (parentFolderId == null) {
      _playlists.add(folder);
    } else {
      _addItemToFolder(_playlists, parentFolderId, folder);
    }
    await _savePlaylists();
    return id;
  }

  bool _addItemToFolder(List<PlaylistEntity> list, String folderId, PlaylistEntity item) {
    for (int i = 0; i < list.length; i++) {
      if (list[i].id == folderId) {
        final sub = List<PlaylistEntity>.from(list[i].subPlaylists)..add(item);
        list[i] = _copyWithSub(list[i], sub).copyWith(isFolder: true);
        return true;
      }
      if (list[i].isFolder || list[i].subPlaylists.isNotEmpty) {
        final sub = List<PlaylistEntity>.from(list[i].subPlaylists);
        if (_addItemToFolder(sub, folderId, item)) {
          list[i] = _copyWithSub(list[i], sub).copyWith(isFolder: true);
          return true;
        }
      }
    }
    return false;
  }

  Future<void> movePlaylistToFolder(String playlistId, String? folderId) async {
    if (playlistId == folderId) return;

    PlaylistEntity? itemToMove;
    PlaylistEntity? findItem(List<PlaylistEntity> list, String id) {
      for (var p in list) {
        if (p.id == id) return p;
        if (p.isFolder) {
          final res = findItem(p.subPlaylists, id);
          if (res != null) return res;
        }
      }
      return null;
    }

    itemToMove = findItem(_playlists, playlistId);
    if (itemToMove == null) return;

    bool removeFromList(List<PlaylistEntity> list, String id) {
      for (int i = 0; i < list.length; i++) {
        if (list[i].id == id) {
          list.removeAt(i);
          return true;
        }
        if (list[i].isFolder) {
          final sub = List<PlaylistEntity>.from(list[i].subPlaylists);
          if (removeFromList(sub, id)) {
            list[i] = _copyWithSub(list[i], sub);
            return true;
          }
        }
      }
      return false;
    }

    removeFromList(_playlists, playlistId);

    if (folderId == null) {
      _playlists.add(itemToMove);
    } else {
      _addItemToFolder(_playlists, folderId, itemToMove);
    }

    await _savePlaylists();
  }

  PlaylistEntity _copyWithSub(PlaylistEntity p, List<PlaylistEntity> sub) {
    return PlaylistEntity(
      id: p.id,
      title: p.title,
      description: p.description,
      thumbnailUrl: p.thumbnailUrl,
      author: p.author,
      trackCount: p.trackCount,
      tracks: p.tracks,
      isFolder: p.isFolder,
      subPlaylists: sub,
    );
  }

  Future<void> importPlaylist(PlaylistEntity playlist, {String? parentFolderId}) async {
    // Cache all songs so they can be retrieved by ID
    for (final song in playlist.tracks) {
      _idToSong[song.id] = song;
    }

    // Fallback to first track's thumbnail if playlist thumbnail is null
    String? thumbUrl = playlist.thumbnailUrl;
    if (thumbUrl == null && playlist.tracks.isNotEmpty) {
      thumbUrl = playlist.tracks.first.bestThumbnail;
    }

    if (parentFolderId != null) {
      // If we are importing into an empty folder, merge it instead of nesting
      if (_mergeIntoEmptyFolder(_playlists, parentFolderId, playlist, thumbUrl)) {
        await _savePlaylists();
        return;
      }
    }

    final isMix = playlist.id.startsWith('RD');
    final defaultDesc = isMix 
        ? 'Mix dinámico basado en ${playlist.tracks.isNotEmpty ? playlist.tracks.first.artist : "YouTube"}'
        : 'Importada desde YouTube';

    final newPlaylist = PlaylistEntity(
      id: const Uuid().v4(),
      title: playlist.title,
      description: (playlist.description == null || playlist.description!.isEmpty)
          ? defaultDesc 
          : playlist.description,
      thumbnailUrl: thumbUrl,
      author: 'YouTube',
      trackCount: playlist.tracks.length,
      tracks: playlist.tracks,
    );
    
    if (parentFolderId == null) {
      _playlists.add(newPlaylist);
    } else {
      _addItemToFolder(_playlists, parentFolderId, newPlaylist);
    }
    
    await _savePlaylists();
  }

  bool _mergeIntoEmptyFolder(List<PlaylistEntity> list, String folderId, PlaylistEntity data, String? thumbUrl) {
    for (int i = 0; i < list.length; i++) {
      if (list[i].id == folderId) {
        // Only merge if the folder is essentially empty (placeholder) 
        // OR if it has songs/subs but we want to append? 
        // User reports "empty folder", so let's check for emptiness.
        if (list[i].tracks.isEmpty && list[i].subPlaylists.isEmpty) {
          list[i] = list[i].copyWith(
            title: list[i].title == 'Nueva Playlist' ? data.title : list[i].title, // Keep user title if they custom-named it
            description: data.description ?? 'Importada desde YouTube',
            thumbnailUrl: thumbUrl ?? list[i].thumbnailUrl,
            tracks: data.tracks,
            trackCount: data.tracks.length,
            isFolder: false, // Convert to playlist since it now has tracks
          );
          return true;
        }
        return false;
      }
      if (list[i].isFolder) {
        final sub = List<PlaylistEntity>.from(list[i].subPlaylists);
        if (_mergeIntoEmptyFolder(sub, folderId, data, thumbUrl)) {
          list[i] = _copyWithSub(list[i], sub);
          return true;
        }
      }
    }
    return false;
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _savePlaylists();
  }

  Future<void> addSongToPlaylist(String playlistId, SongEntity song) async {
    bool found = false;
    void searchAndAdd(List<PlaylistEntity> list) {
      for (int i = 0; i < list.length; i++) {
        if (list[i].id == playlistId && !list[i].isFolder) {
          if (!list[i].tracks.any((s) => s.id == song.id)) {
            final updatedTracks = List<SongEntity>.from(list[i].tracks)..add(song);
            list[i] = PlaylistEntity(
              id: list[i].id,
              title: list[i].title,
              description: list[i].description,
              thumbnailUrl: list[i].thumbnailUrl ?? song.thumbnailUrl,
              author: list[i].author,
              trackCount: updatedTracks.length,
              tracks: updatedTracks,
            );
          }
          found = true;
          return;
        }
        if (list[i].isFolder) {
          final sub = List<PlaylistEntity>.from(list[i].subPlaylists);
          searchAndAdd(sub);
          list[i] = _copyWithSub(list[i], sub);
          if (found) return;
        }
      }
    }

    searchAndAdd(_playlists);
    if (found) await _savePlaylists();
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    bool found = false;
    void searchAndRemove(List<PlaylistEntity> list) {
      for (int i = 0; i < list.length; i++) {
        if (list[i].id == playlistId && !list[i].isFolder) {
          final updatedTracks = List<SongEntity>.from(list[i].tracks)
              ..removeWhere((s) => s.id == songId);
          list[i] = PlaylistEntity(
            id: list[i].id,
            title: list[i].title,
            description: list[i].description,
            thumbnailUrl: updatedTracks.isNotEmpty ? updatedTracks.first.thumbnailUrl : null,
            author: list[i].author,
            trackCount: updatedTracks.length,
            tracks: updatedTracks,
          );
          found = true;
          return;
        }
        if (list[i].isFolder) {
          final sub = List<PlaylistEntity>.from(list[i].subPlaylists);
          searchAndRemove(sub);
          list[i] = _copyWithSub(list[i], sub);
          if (found) return;
        }
      }
    }

    searchAndRemove(_playlists);
    if (found) await _savePlaylists();
  }

  Future<void> _savePlaylists() async {
    await _prefs.setStringList(
      _playlistsKey,
      _playlists.map((p) => jsonEncode(UserPlaylistModel.fromEntity(p).toJson())).toList(),
    );
    notifyListeners();
  }

  // --- Like & History ---

  bool isLiked(String songId) => _likedSongs.any((s) => s.id == songId);

  Future<void> toggleLike(SongEntity song) async {
    _idToSong[song.id] = song;
    final index = _likedSongs.indexWhere((s) => s.id == song.id);
    if (index >= 0) {
      _likedSongs.removeAt(index);
    } else {
      _likedSongs.insert(0, song);
    }
    
    await _prefs.setStringList(
      _likedKey,
      _likedSongs.map((s) => jsonEncode(SongModel.fromEntity(s).toJson())).toList(),
    );
    notifyListeners();
  }

  Future<void> addToHistory(SongEntity song) async {
    _idToSong[song.id] = song;
    
    // Update Play Counts
    _playCounts[song.id] = (_playCounts[song.id] ?? 0) + 1;
    await _prefs.setString(_countsKey, jsonEncode(_playCounts));

    // Remove if already exists to move it to the top
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    _recentlyPlayed.insert(0, song);
    
    if (_recentlyPlayed.length > _maxRecent) {
      _recentlyPlayed = _recentlyPlayed.sublist(0, _maxRecent);
    }

    await _prefs.setStringList(
      _recentKey,
      _recentlyPlayed.map((s) => jsonEncode(SongModel.fromEntity(s).toJson())).toList(),
    );
    notifyListeners();
  }


  List<SongEntity> getMostPlayedSongs({int limit = 20}) {
    final sortedIds = _playCounts.keys.toList()
      ..sort((a, b) => _playCounts[b]!.compareTo(_playCounts[a]!));
    
    return sortedIds
        .map((id) => _idToSong[id])
        .whereType<SongEntity>()
        .take(limit)
        .toList();
  }

  List<SongEntity> getEnergyMix() {
    final energyKeywords = ['rock', 'metal', 'heavy', 'energy', 'electro', 'trap', 'remix', 'gym', 'workout', 'bass', 'hard', 'epic'];
    final allSongs = _idToSong.values.toSet().toList();
    
    final matches = allSongs.where((s) {
      final text = (s.title + s.artist).toLowerCase();
      return energyKeywords.any((k) => text.contains(k));
    }).toList();
    
    if (matches.length < 5) return (allSongs..shuffle()).take(50).toList();
    return (matches..shuffle()).take(50).toList();
  }

  List<SongEntity> getChillMix() {
    final chillKeywords = ['chill', 'lofi', 'lo-fi', 'jazz', 'ambient', 'piano', 'acoustic', 'soft', 'relax', 'night', 'slow', 'peace', 'sleep'];
    final allSongs = _idToSong.values.toSet().toList();
    
    final matches = allSongs.where((s) {
      final text = (s.title + s.artist).toLowerCase();
      return chillKeywords.any((k) => text.contains(k));
    }).toList();
    
    if (matches.length < 5) return (allSongs..shuffle()).take(50).toList();
    return (matches..shuffle()).take(50).toList();
  }
}
