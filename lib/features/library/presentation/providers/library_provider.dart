import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../data/models/song_model.dart';

class LibraryProvider with ChangeNotifier {
  final SharedPreferences _prefs;
  
  List<SongEntity> _likedSongs = [];
  List<SongEntity> _recentlyPlayed = [];
  
  static const String _likedKey = 'liked_songs';
  static const String _recentKey = 'recent_played';
  static const String _countsKey = 'play_counts';
  static const int _maxRecent = 100;

  Map<String, int> _playCounts = {};
  Map<String, SongEntity> _idToSong = {};

  LibraryProvider(this._prefs) {
    refreshData();
  }

  List<SongEntity> get likedSongs => _likedSongs;
  List<SongEntity> get recentlyPlayed => _recentlyPlayed;

  SongEntity? getSong(String id) => _idToSong[id];
  int getPlayCount(String id) => _playCounts[id] ?? 0;

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
    
    final countsJson = _prefs.getString(_countsKey);
    if (countsJson != null) {
      _playCounts = Map<String, int>.from(jsonDecode(countsJson));
    }
    
    notifyListeners();
  }

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
