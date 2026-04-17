import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../domain/entities/entities.dart';

class StatsProvider with ChangeNotifier {
  final SharedPreferences _prefs;

  static const String _sessionStatsKey = 'session_stats';
  static const String _playCountsKey = 'play_counts';
  static const String _genreStatsKey = 'genre_stats';

  Map<String, int> _playCounts = {};
  Map<String, int> _genreCounts = {};
  int _totalMinutes = 0;
  DateTime _lastUpdate = DateTime.now();

  StatsProvider(this._prefs) {
    _loadStats();
  }

  int get totalMinutes => _totalMinutes;
  Map<String, int> get playCounts => _playCounts;
  Map<String, int> get genreCounts => _genreCounts;

  void _loadStats() {
    final countsJson = _prefs.getString(_playCountsKey);
    if (countsJson != null) {
      _playCounts = Map<String, int>.from(jsonDecode(countsJson));
    }

    final genresJson = _prefs.getString(_genreStatsKey);
    if (genresJson != null) {
      _genreCounts = Map<String, int>.from(jsonDecode(genresJson));
    }

    _totalMinutes = _prefs.getInt('total_listening_minutes') ?? 0;
    notifyListeners();
  }

  Future<void> trackPlay(SongEntity song) async {
    // Incrementar conteo de reproducciones
    _playCounts[song.id] = (_playCounts[song.id] ?? 0) + 1;
    
    // Simular detección de género basado en palabras clave o artista
    final genre = _detectGenre(song);
    _genreCounts[genre] = (_genreCounts[genre] ?? 0) + 1;

    // Actualizar minutos escuchados con la duración real (o 3 min como fallback)
    final durationMinutes = song.duration.inMinutes > 0 ? song.duration.inMinutes : 3;
    _totalMinutes += durationMinutes; 

    await _saveStats();
    notifyListeners();
  }

  String _detectGenre(SongEntity song) {
    final text = (song.title + song.artist).toLowerCase();
    if (text.contains('rock') || text.contains('heavy') || text.contains('metal')) return 'Rock';
    if (text.contains('trap') || text.contains('rap') || text.contains('hip hop')) return 'Urbano';
    if (text.contains('pop') || text.contains('dance')) return 'Pop';
    if (text.contains('techno') || text.contains('house') || text.contains('electro')) return 'Electro';
    if (text.contains('lofi') || text.contains('chill') || text.contains('jazz')) return 'Relax';
    return 'Otros';
  }

  Future<void> _saveStats() async {
    await _prefs.setString(_playCountsKey, jsonEncode(_playCounts));
    await _prefs.setString(_genreStatsKey, jsonEncode(_genreCounts));
    await _prefs.setInt('total_listening_minutes', _totalMinutes);
  }

  List<MapEntry<String, int>> getTopGenres({int limit = 5}) {
    final sorted = _genreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  double getGenrePercentage(String genre) {
    if (_genreCounts.isEmpty) return 0.0;
    final total = _genreCounts.values.fold(0, (sum, val) => sum + val);
    return (_genreCounts[genre] ?? 0) / total;
  }
}
