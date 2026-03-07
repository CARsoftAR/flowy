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
  static const int _maxRecent = 50;

  LibraryProvider(this._prefs) {
    _loadData();
  }

  List<SongEntity> get likedSongs => _likedSongs;
  List<SongEntity> get recentlyPlayed => _recentlyPlayed;

  bool isLiked(String songId) => _likedSongs.any((s) => s.id == songId);

  void _loadData() {
    final likedJson = _prefs.getStringList(_likedKey) ?? [];
    _likedSongs = likedJson
        .map((j) => SongModel.fromJson(jsonDecode(j)).toSongEntity())
        .toList();

    final recentJson = _prefs.getStringList(_recentKey) ?? [];
    _recentlyPlayed = recentJson
        .map((j) => SongModel.fromJson(jsonDecode(j)).toSongEntity())
        .toList();
    
    notifyListeners();
  }

  Future<void> toggleLike(SongEntity song) async {
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
}
