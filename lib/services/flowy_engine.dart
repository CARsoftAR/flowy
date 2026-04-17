import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ConnectionStatus { checking, connected, degraded, offline }

class FlowyEngine {
  static const String _gistUrl =
      'https://gist.githubusercontent.com/CARsoftAR/8899fe3ba29b12c82a923c9a3d73fad1/raw/flowy_config.json';

  // Pool de instancias Invidious (ordenadas por prioridad)
  static const List<String> _invidiousPool = [
    'https://inv.nadeko.net',
    'https://invidious.nerdvpn.de',
    'https://invidious.privacyredirect.com',
    'https://yt.cdaut.de',
    'https://invidious.fdn.fr',
    'https://yewtu.be',
  ];

  static const String _testVideoId = 'dQw4w9WgXcQ';
  static const String _cacheKey = 'flowy_invidious_url';

  static String currentApiUrl = '';
  static final ValueNotifier<ConnectionStatus> status =
      ValueNotifier(ConnectionStatus.checking);

  static Future<void> initialize() async {
    debugPrint('🚀 FlowyEngine: Iniciando...');
    status.value = ConnectionStatus.checking;

    // 1. Intentar cache primero (stale-while-revalidate)
    final cachedUrl = await _loadCachedUrl();
    if (cachedUrl != null && await _quickPing(cachedUrl, 2)) {
      currentApiUrl = cachedUrl;
      debugPrint('✅ Cache: $currentApiUrl');
      status.value = ConnectionStatus.connected;
      return;
    }

    // 2. Intentar Gist
    String? gistUrl = await _fetchFromGist();
    if (gistUrl != null && await _quickPing(gistUrl, 3)) {
      currentApiUrl = gistUrl;
      await _saveCache(gistUrl);
      debugPrint('✅ Gist: $currentApiUrl');
      status.value = ConnectionStatus.connected;
      return;
    }

    // 3. Health check paralelo en pool
    debugPrint('⚡ Escaneando pool de instancias...');
    final working = await _findWorkingInstance();
    if (working != null) {
      currentApiUrl = working;
      await _saveCache(working);
      debugPrint('✅ Pool: $currentApiUrl');
      status.value = ConnectionStatus.connected;
      return;
    }

    // 4. Todo falló - fallback a YoutubeExplode
    currentApiUrl = '';
    status.value = ConnectionStatus.degraded;
    debugPrint('⚠️ Fallback: Sin Invidious, usando YoutubeExplode');
  }

  // ── Cache ─────────────────────────────────────────────────────────
  static Future<String?> _loadCachedUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_cacheKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> _saveCache(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, url);
    } catch (e) {
      // Silently fail
    }
  }

  // ── Gist ────────────────────────────────────────────────────────────
  static Future<String?> _fetchFromGist() async {
    try {
      final response = await http
          .get(Uri.parse(_gistUrl))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['api_url']?.toString().replaceAll(RegExp(r'/$'), '');
      }
    } catch (e) {
      debugPrint('Gist error: $e');
    }
    return null;
  }

  // ── Ping Rápido (2-3s) ───────────────────────────────────────────
  static Future<bool> _quickPing(String instance, int timeoutSecs) async {
    try {
      final response = await http
          .get(
            Uri.parse('$instance/api/v1/videos/$_testVideoId'),
          )
          .timeout(Duration(seconds: timeoutSecs));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── Health Check Paralelo ──────────────────────────────────────
  static Future<String?> _findWorkingInstance() async {
    final results = await Future.wait(
      _invidiousPool.map((instance) async {
        final works = await _quickPing(instance, 3);
        return works ? instance : null;
      }),
      eagerError: false,
    );

    for (final result in results) {
      if (result != null) return result;
    }
    return null;
  }

  /// Refrescar manualmente
  static Future<void> refresh() async {
    await initialize();
  }
}
