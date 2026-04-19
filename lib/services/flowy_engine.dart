import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ConnectionStatus { checking, connected, degraded, offline }

enum ProviderType { invidious, piped, youtubeDirect }

class ProviderInfo {
  final String name;
  final String url;
  final ProviderType type;
  final bool isWorking;
  final int latencyMs;

  const ProviderInfo({
    required this.name,
    required this.url,
    required this.type,
    this.isWorking = false,
    this.latencyMs = 0,
  });

  ProviderInfo copyWith({bool? isWorking, int? latencyMs}) {
    return ProviderInfo(
      name: name,
      url: url,
      type: type,
      isWorking: isWorking ?? this.isWorking,
      latencyMs: latencyMs ?? this.latencyMs,
    );
  }
}

class FlowyEngine {
  static const String _gistUrl =
      'https://gist.githubusercontent.com/CARsoftAR/8899fe3ba29b12c82a923c9a3d73fad1/raw/flowy_config.json';

  static const String _testVideoId = 'dQw4w9WgXcQ';
  static const String _cacheKey = 'flowy_provider_url';
  static const String _providerTypeKey = 'flowy_provider_type';

  static String currentApiUrl = '';
  static ProviderType currentProviderType = ProviderType.invidious;
  static final ValueNotifier<ConnectionStatus> status =
      ValueNotifier(ConnectionStatus.checking);
  static final ValueNotifier<List<ProviderInfo>> availableProviders =
      ValueNotifier([]);

  static final List<ProviderInfo> _allProviders = [
    const ProviderInfo(
      name: 'Invidious (Nadeko)',
      url: 'https://inv.nadeko.net',
      type: ProviderType.invidious,
    ),
    const ProviderInfo(
      name: 'Invidious (Privacy)',
      url: 'https://invidious.privacyredirect.com',
      type: ProviderType.invidious,
    ),
    const ProviderInfo(
      name: 'Invidious (Yewtu)',
      url: 'https://yewtu.be',
      type: ProviderType.invidious,
    ),
    const ProviderInfo(
      name: 'Piped (Official)',
      url: 'https://api.piped.yt',
      type: ProviderType.piped,
    ),
    const ProviderInfo(
      name: 'YouTube Direct',
      url: '',
      type: ProviderType.youtubeDirect,
    ),
  ];

  static Future<void> initialize() async {
    debugPrint('🚀 FlowyEngine: Iniciando...');
    status.value = ConnectionStatus.checking;

    final cachedUrl = await _loadCachedUrl();
    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      currentApiUrl = cachedUrl;
      final cachedType = await _loadProviderType();
      currentProviderType = cachedType ?? ProviderType.invidious;
      status.value = ConnectionStatus.connected;
      debugPrint('✅ Cache: $currentApiUrl');
      return;
    }

    final gistUrl = await _fetchFromGist();
    if (gistUrl != null && gistUrl.isNotEmpty) {
      currentApiUrl = gistUrl;
      await _saveCache(gistUrl);
      status.value = ConnectionStatus.connected;
      debugPrint('✅ Gist: $currentApiUrl');
      return;
    }

    currentProviderType = ProviderType.invidious;
    currentApiUrl = 'https://inv.nadeko.net';
    status.value = ConnectionStatus.connected;
    debugPrint('✅ Default: $currentApiUrl');
  }

  static Future<void> refresh() async {
    debugPrint('🔄 FlowyEngine.refresh()');

    try {
      final working = await _findWorkingInstance();
      if (working != null) {
        currentApiUrl = working;
        currentProviderType = ProviderType.invidious;
        await _saveCache(working);
        status.value = ConnectionStatus.connected;
        debugPrint('✅ Provider: $working');
      } else {
        _useOfflineMode();
      }
    } catch (e) {
      _useOfflineMode();
      debugPrint('⚠️ Error: $e');
    }
  }

  static void _useOfflineMode() {
    currentApiUrl = '';
    currentProviderType = ProviderType.youtubeDirect;
    status.value = ConnectionStatus.degraded;
    debugPrint('⚠️ Offline mode');
  }

  static Future<String?> _findWorkingInstance() async {
    for (final provider in _allProviders) {
      if (provider.type == ProviderType.youtubeDirect) continue;
      if (await _quickPing(provider.url, 2)) {
        return provider.url;
      }
    }
    return null;
  }

  static Future<String?> _loadCachedUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_cacheKey);
    } catch (e) {
      return null;
    }
  }

  static Future<ProviderType?> _loadProviderType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt(_providerTypeKey);
      if (index != null && index < ProviderType.values.length) {
        return ProviderType.values[index];
      }
    } catch (e) {}
    return null;
  }

  static Future<void> _saveCache(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, url);
    } catch (e) {}
  }

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

  static Future<bool> _quickPing(String instance, int timeoutSecs) async {
    if (instance.isEmpty) return true;
    try {
      final response = await http
          .get(Uri.parse('$instance/api/v1/videos/$_testVideoId'))
          .timeout(Duration(seconds: timeoutSecs));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static List<ProviderInfo> get providers => availableProviders.value;

  static String get currentProviderName {
    if (currentApiUrl.isEmpty) return 'YouTube Direct';
    final provider =
        _allProviders.where((p) => p.url == currentApiUrl).firstOrNull;
    return provider?.name ?? 'Unknown';
  }

  static Future<void> switchProvider(ProviderInfo provider) async {
    currentApiUrl = provider.url;
    currentProviderType = provider.type;
    await _saveCache(provider.url);
    status.value = provider.isWorking
        ? ConnectionStatus.connected
        : ConnectionStatus.degraded;
    debugPrint('🔄 Switched to: ${provider.name}');
  }
}
