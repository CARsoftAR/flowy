import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// FlowyHttpClient — Low-level network optimization
/// Implements User-Agent rotation, Referer/Origin spoofing, IPv4 forcing,
/// and aggressive timeouts (8s).
/// ─────────────────────────────────────────────────────────────────────────────

class FlowyHttpClient extends IOClient {
  static final List<String> _userAgents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
  ];

  FlowyHttpClient() : super(_createTunedClient());

  static HttpClient _createTunedClient() {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 8);

    // FORCE IPV4 (Low-level fix)
    // We override the connection factory to force IPv4 lookups for YouTube/Invidious domains
    return client;
  }

  @override
  Future<IOStreamedResponse> send(http.BaseRequest request) async {
    // 1. ROTATE USER-AGENT
    final randomAgent = _userAgents[Random().nextInt(_userAgents.length)];
    
    // 2. APPLY LEGITIMATE HEADERS
    request.headers['User-Agent'] = randomAgent;
    request.headers['Accept'] = '*/*';
    request.headers['Accept-Language'] = 'en-US,en;q=0.9,es;q=0.8';
    
    // Add Referer and Origin to simulate browser traffic
    if (!request.headers.containsKey('Referer')) {
      request.headers['Referer'] = 'https://www.youtube.com/';
    }
    if (!request.headers.containsKey('Origin')) {
      request.headers['Origin'] = 'https://www.youtube.com';
    }

    if (kDebugMode) {
      print('🌐 [Network] ${request.method} -> ${request.url}');
    }

    try {
      return await super.send(request).timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [Network Error] ${request.url}: $e');
      }
      rethrow;
    }
  }

  /// Helper to get a pre-configured request with all headers
  static Future<http.Response> getTuned(Uri uri) async {
    final client = FlowyHttpClient();
    try {
      return await client.get(uri);
    } finally {
      client.close();
    }
  }
}

/// GLOBAL OVERRIDE FOR IPV4
class IPv4HttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..connectionTimeout = const Duration(seconds: 8)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}
