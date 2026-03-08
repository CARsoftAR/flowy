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
    if (totalDuration.inSeconds == 0) return 0.0;
    final seconds = _prefs.getInt('bookmark_$songId') ?? 0;
    if (seconds <= 10) return 0.0;
    return (seconds / totalDuration.inSeconds).clamp(0.0, 1.0);
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

  Future<void> createPlaylist(String title, {String? description}) async {
    final playlist = PlaylistEntity(
      id: const Uuid().v4(),
      title: title,
      description: description,
      tracks: const [],
    );
    _playlists.add(playlist);
    await _savePlaylists();
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _savePlaylists();
  }

  Future<void> addSongToPlaylist(String playlistId, SongEntity song) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;

    final playlist = _playlists[index];
    if (playlist.tracks.any((s) => s.id == song.id)) return;

    final updatedTracks = List<SongEntity>.from(playlist.tracks)..add(song);
    _playlists[index] = PlaylistEntity(
      id: playlist.id,
      title: playlist.title,
      description: playlist.description,
      thumbnailUrl: playlist.thumbnailUrl ?? song.thumbnailUrl,
      author: playlist.author,
      trackCount: updatedTracks.length,
      tracks: updatedTracks,
    );

    await _savePlaylists();
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;

    final playlist = _playlists[index];
    final updatedTracks = List<SongEntity>.from(playlist.tracks)
      ..removeWhere((s) => s.id == songId);

    _playlists[index] = PlaylistEntity(
      id: playlist.id,
      title: playlist.title,
      description: playlist.description,
      thumbnailUrl: updatedTracks.isNotEmpty ? updatedTracks.first.thumbnailUrl : null,
      author: playlist.author,
      trackCount: updatedTracks.length,
      tracks: updatedTracks,
    );

    await _savePlaylists();
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
    
    if (matches.length < 5) return (allSongs..shuffle()).take(10).toList();
    return (matches..shuffle()).take(15).toList();
  }

  List<SongEntity> getChillMix() {
    final chillKeywords = ['chill', 'lofi', 'lo-fi', 'jazz', 'ambient', 'piano', 'acoustic', 'soft', 'relax', 'night', 'slow', 'peace', 'sleep'];
    final allSongs = _idToSong.values.toSet().toList();
    
    final matches = allSongs.where((s) {
      final text = (s.title + s.artist).toLowerCase();
      return chillKeywords.any((k) => text.contains(k));
    }).toList();
    
    if (matches.length < 5) return (allSongs..shuffle()).take(10).toList();
    return (matches..shuffle()).take(15).toList();
  }
}
