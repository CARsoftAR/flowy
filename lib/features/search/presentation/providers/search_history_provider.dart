
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryProvider extends ChangeNotifier {
  final List<String> _history = [];
  static const String _key = 'recent_searches';

  SearchHistoryProvider() {
    _loadHistory();
  }

  List<String> get history => List.unmodifiable(_history);

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    _history.addAll(list);
    notifyListeners();
  }

  Future<void> addQuery(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    _history.remove(q);
    _history.insert(0, q);
    if (_history.length > 20) _history.removeLast();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _history);
    notifyListeners();
  }

  Future<void> removeQuery(String query) async {
    _history.remove(query);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _history);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    notifyListeners();
  }
}
