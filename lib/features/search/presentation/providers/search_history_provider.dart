
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
    await _loadCustomInterests(prefs);
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

  // ── Custom Interests (User Generated Cards) ──

  final List<Map<String, String>> _customInterests = [];
  static const String _interestKey = 'custom_interests';

  List<Map<String, String>> get customInterests => List.unmodifiable(_customInterests);

  Future<void> _loadCustomInterests(SharedPreferences prefs) async {
    final list = prefs.getStringList(_interestKey) ?? [];
    for (final item in list) {
      final parts = item.split('|||'); // format: id|||title|||category
      if (parts.length == 3) {
        _customInterests.add({'id': parts[0], 'title': parts[1], 'category': parts[2]});
      }
    }
  }

  Future<void> addCustomInterest(String title, String category) async {
    final t = title.trim();
    if (t.isEmpty) return;
    
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    _customInterests.add({'id': id, 'title': t, 'category': category});
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_interestKey, 
      _customInterests.map((e) => '${e['id']}|||${e['title']}|||${e['category']}').toList()
    );
    notifyListeners();
  }

  Future<void> removeCustomInterest(String id) async {
    _customInterests.removeWhere((e) => e['id'] == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_interestKey, 
      _customInterests.map((e) => '${e['id']}|||${e['title']}|||${e['category']}').toList()
    );
    notifyListeners();
  }
}
