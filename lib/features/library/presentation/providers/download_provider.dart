
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../domain/entities/entities.dart';

class DownloadProvider extends ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 120),
    sendTimeout: const Duration(seconds: 20),
  ));

  // Headers de alta fidelidad para simular un navegador y evitar límites de velocidad
  static const Map<String, String> _optimizedHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://www.youtube.com/',
    'Origin': 'https://www.youtube.com/',
    'Connection': 'keep-alive',
    'Sec-Fetch-Dest': 'empty',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Site': 'cross-site',
  };

  final Set<String> _downloadedIds = {};
  final Map<String, SongEntity> _downloadedMetadata = {};
  final Set<String> _fetchingIds = {};
  final Map<String, double?> _progress = {};
  final Map<String, CancelToken> _cancelTokens = {};
  
  // Configuración de suscripción y límites
  bool _isPremium = false;
  static const int MAX_FREE_DOWNLOADS = 5;

  bool get isPremium => _isPremium;
  int get remainingFreeDownloads => MAX_FREE_DOWNLOADS - _downloadedIds.length;
  bool get canDownloadMore => _isPremium || _downloadedIds.length < MAX_FREE_DOWNLOADS;
  
  // Configuración de descarga ultra-agresiva
  static const int _numChunks = 8; 
  static const int _maxConcurrent = 8;
  
  DownloadProvider() {
    _loadDownloadedList();
  }

  Set<String> get downloadedIds => _downloadedIds;
  List<SongEntity> get downloadedSongs => _downloadedMetadata.values.toList();
  double? getProgress(String id) => _progress[id];
  bool isDownloaded(String id) => _downloadedIds.contains(id);
  bool isDownloading(String id) => _progress.containsKey(id);
  bool isFetching(String id) => _fetchingIds.contains(id);

  void setFetching(String id, bool active) {
    if (active) {
      _fetchingIds.add(id);
    } else {
      _fetchingIds.remove(id);
    }
    notifyListeners();
  }

  Future<void> _loadDownloadedList() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('downloaded_songs') ?? [];
    final metaJson = prefs.getString('downloaded_metadata_v2');
    
    _downloadedIds.addAll(list);
    
    if (metaJson != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(metaJson);
        decoded.forEach((key, value) {
          final m = Map<String, dynamic>.from(value);
          _downloadedMetadata[key] = SongEntity(
            id: m['id'] ?? key,
            title: m['title'] ?? '',
            artist: m['artist'] ?? '',
            thumbnailUrl: m['thumb'],
            duration: Duration(seconds: m['dur'] ?? 0),
          );
        });
      } catch (e) {
        debugPrint('[DownloadProvider] Error decoding metadata: $e');
      }
    }

    // Verify files still exist
    final dir = await getApplicationDocumentsDirectory();
    final toRemove = <String>[];
    for (final id in _downloadedIds) {
      final file = File('${dir.path}/downloads/$id.mp3');
      if (!await file.exists() || await file.length() == 0) {
        toRemove.add(id);
      }
    }
    
    if (toRemove.isNotEmpty) {
      _downloadedIds.removeAll(toRemove);
      for (final id in toRemove) {
        _downloadedMetadata.remove(id);
      }
      await _saveDownloadedList();
    }
    
    notifyListeners();
  }

  Future<void> _saveDownloadedList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('downloaded_songs', _downloadedIds.toList());
    
    final Map<String, dynamic> metaMap = {};
    _downloadedMetadata.forEach((key, s) {
      metaMap[key] = {
        'id': s.id,
        'title': s.title,
        'artist': s.artist,
        'thumb': s.thumbnailUrl,
        'dur': s.duration.inSeconds,
      };
    });
    await prefs.setString('downloaded_metadata_v2', json.encode(metaMap));
  }

  Future<String> getLocalPath(String id) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/downloads/$id.mp3';
  }

  Future<bool> downloadSong(SongEntity song, String streamUrl, {required BuildContext context}) async {
    if (isDownloaded(song.id) || isDownloading(song.id)) return false;

    // Verificar límite de versión Free
    if (!canDownloadMore) {
      _showPremiumRequiredDialog(context);
      return false;
    }

    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    final savePath = '${downloadDir.path}/${song.id}.mp3';
    
    final cancelToken = CancelToken();
    _cancelTokens[song.id] = cancelToken;

    try {
      _progress[song.id] = 0.0;
      notifyListeners();

      // Implementación de descarga ultra-rápida usando 3 conexiones paralelas (Chunks)
      await _acceleratedDownload(song.id, streamUrl, savePath, cancelToken);

      // Verify file integrity
      final file = File(savePath);
      if (await file.exists() && await file.length() > 0) {
        _downloadedIds.add(song.id);
        _downloadedMetadata[song.id] = song;
        await _saveDownloadedList();
        return true;
      } else {
        throw Exception('File saved but is empty or missing');
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        debugPrint('[DownloadProvider] Download cancelled: ${song.title}');
        final file = File(savePath);
        if (await file.exists()) await file.delete();
      } else {
        debugPrint('[DownloadProvider] Error downloading ${song.title}: $e');
        final file = File(savePath);
        if (await file.exists()) await file.delete();
      }
      return false;
    } finally {
      _cancelTokens.remove(song.id);
      _progress.remove(song.id);
      notifyListeners();
    }
  }

  Future<void> _acceleratedDownload(String id, String url, String path, CancelToken token) async {
    try {
      // 1. Obtener Metadatos y Tamaño (usando un rango de 1 byte para forzar respuesta de servidor)
      final headRes = await _dio.get(url, options: Options(
        headers: {..._optimizedHeaders, 'Range': 'bytes=0-0'},
        followRedirects: true,
      ));
      
      final total = int.tryParse(headRes.headers.value('content-range')?.split('/').last ?? '') ?? 
                    int.tryParse(headRes.headers.value('content-length') ?? '') ?? 0;

      // Si no podemos determinar tamaño o es pequeño (< 3MB), descarga estándar optimizada
      if (total < 3 * 1024 * 1024) {
        await _dio.download(url, path, cancelToken: token, options: Options(headers: _optimizedHeaders),
          onReceiveProgress: (r, t) {
            if (t > 0) { _progress[id] = r / t; notifyListeners(); }
          }
        );
        return;
      }

      // 2. Configurar 8 hilos de descarga paralelos para saturar el ancho de banda
      const int chunks = _numChunks;
      final int chunkSize = (total / chunks).ceil();
      final List<String> partPaths = List.generate(chunks, (i) => '$path.part$i');
      final List<int> progressList = List.filled(chunks, 0);
      
      // Usamos un limitador de concurrencia implícito con Future.wait
      final futures = <Future>[];
      for (int i = 0; i < chunks; i++) {
        final start = i * chunkSize;
        final end = (i == chunks - 1) ? total - 1 : (i + 1) * chunkSize - 1;
        
        // Cada hilo tiene su propio reintento interno para evitar que un fallo de red tire toda la descarga
        futures.add(_downloadChunk(url, partPaths[i], start, end, token, (received) {
          progressList[i] = received;
          final sum = progressList.reduce((a, b) => a + b);
          _progress[id] = sum / total;
          notifyListeners();
        }));
      }

      await Future.wait(futures);

      // 3. Ensamblaje atómico de los fragmentos
      final outputFile = File(path);
      final sink = outputFile.openWrite();
      for (final p in partPaths) {
        final f = File(p);
        await sink.addStream(f.openRead());
        await f.delete();
      }
      await sink.close();
      
    } catch (e) {
      // Limpieza preventiva de todos los fragmentos (.part0, .part1, ...)
      for (int i = 0; i < _numChunks; i++) {
        final f = File('$path.part$i');
        if (await f.exists()) await f.delete();
      }
      rethrow;
    }
  }

  /// Descarga un fragmento específico con lógica de reintento para máxima fiabilidad
  Future<void> _downloadChunk(String url, String path, int start, int end, CancelToken token, Function(int) onProgress) async {
    int retryCount = 0;
    while (retryCount < 3) {
      try {
        await _dio.download(
          url,
          path,
          cancelToken: token,
          options: Options(
            headers: {..._optimizedHeaders, 'Range': 'bytes=$start-$end'},
            receiveTimeout: const Duration(seconds: 45),
          ),
          onReceiveProgress: (received, _) => onProgress(received),
        );
        return; // Éxito
      } catch (e) {
        retryCount++;
        if (retryCount >= 3 || (e is DioException && e.type == DioExceptionType.cancel)) rethrow;
        await Future.delayed(Duration(seconds: 1 * retryCount));
      }
    }
  }

  void cancelDownload(String id) {
    _cancelTokens[id]?.cancel();
  }

  void _showPremiumRequiredDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2131),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Icon(Icons.workspace_premium_rounded, color: scheme.primary, size: 48),
        title: const Text('Límite Alcanzado', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Has alcanzado el límite de 5 descargas de la versión gratuita.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pásate a Flowy Premium para descargas ilimitadas y calidad ultra alta.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white30, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ahora no', style: TextStyle(color: Colors.white24)),
          ),
          ElevatedButton(
            onPressed: () {
              // Aquí iría la lógica de compra, por ahora solo cerramos
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('SER PREMIUM'),
          ),
        ],
      ),
    );
  }

  Future<void> deleteDownload(String id) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/downloads/$id.mp3');
    if (await file.exists()) {
      await file.delete();
    }
    _downloadedIds.remove(id);
    await _saveDownloadedList();
    notifyListeners();
  }
}
