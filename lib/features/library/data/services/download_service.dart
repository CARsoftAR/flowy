import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../../services/flowy_engine.dart';

typedef DownloadProgressCallback = void Function(int received, int total);

class _DownloadTask {
  final String id;
  final String savePath;
  final DownloadProgressCallback onProgress;
  final Completer<bool> completer = Completer<bool>();
  bool _cancelled = false;

  _DownloadTask({
    required this.id,
    required this.savePath,
    required this.onProgress,
  });

  void cancel() => _cancelled = true;
  bool get isCancelled => _cancelled;
}

class DownloadService {
  final YoutubeExplode _yt;
  final Dio _dio = Dio();
  
  DownloadService(this._yt);

  final Queue<_DownloadTask> _queue = Queue();
  final Map<String, _DownloadTask> _taskRegistry = {};
  bool _isProcessing = false;

  Future<bool> enqueue({
    required String id,
    required String savePath,
    required DownloadProgressCallback onProgress,
  }) {
    if (_taskRegistry.containsKey(id)) {
      return _taskRegistry[id]!.completer.future;
    }

    final task = _DownloadTask(id: id, savePath: savePath, onProgress: onProgress);
    _taskRegistry[id] = task;
    _queue.addLast(task);
    _kickQueue();
    return task.completer.future;
  }

  void cancel(String id) => _taskRegistry[id]?.cancel();

  void _kickQueue() {
    if (_isProcessing || _queue.isEmpty) return;
    _processNext();
  }

  void _processNext() {
    if (_queue.isEmpty) {
      _isProcessing = false;
      return;
    }
    _isProcessing = true;
    final task = _queue.removeFirst();
    _run(task).then((_) => Future.microtask(_processNext));
  }

  Future<void> _run(_DownloadTask task) async {
    if (task.isCancelled) {
      _taskRegistry.remove(task.id);
      task.completer.complete(false);
      return;
    }
    try {
      await _downloadAndWrite(task);
    } catch (e) {
      _taskRegistry.remove(task.id);
      debugPrint('[DownloadService] Error: $e');
      task.completer.complete(false);
    }
  }

  Future<void> _downloadAndWrite(_DownloadTask task) async {
    try {
      String? streamUrl;
      int? totalSize;

      // ── PRIMARY ENGINE: Dynamic Invidious API ────────────────────────────────
      try {
        final baseUrl = FlowyEngine.currentApiUrl;
        final response = await http.get(Uri.parse('$baseUrl/api/v1/videos/${task.id}'))
            .timeout(const Duration(seconds: 15));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final adaptiveFormats = data['adaptiveFormats'] as List<dynamic>?;
          
          if (adaptiveFormats != null && adaptiveFormats.isNotEmpty) {
            final audioStreams = adaptiveFormats.where((f) => 
                f['type']?.toString().contains('audio') ?? false).toList();
            
            if (audioStreams.isNotEmpty) {
              audioStreams.sort((a, b) => 
                 ((b['bitrate'] as num?)?.toInt() ?? 0).compareTo((a['bitrate'] as num?)?.toInt() ?? 0));
              
              streamUrl = audioStreams.first['url'] as String?;
              final sizeStr = audioStreams.first['contentLength']?.toString() ?? audioStreams.first['size']?.toString();
              totalSize = int.tryParse(sizeStr ?? '');
              
              if (streamUrl != null) {
                debugPrint('[DownloadService] Dynamic Engine OK for ${task.id}');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[DownloadService] Dynamic Engine failed: $e');
      }

      // ── FALLBACK ENGINE: YoutubeExplode ─────────────────────────────
      if (streamUrl == null) {
        debugPrint('[DownloadService] Using Native Fallback for ${task.id}');
        StreamManifest? manifest;
        try {
          manifest = await _yt.videos.streamsClient.getManifest(
            task.id,
            ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidVr],
          );
        } catch (e) {
          manifest = await _yt.videos.streamsClient.getManifest(
            task.id,
            ytClients: [YoutubeApiClient.android],
          );
        }
        
        final streamInfo = manifest.audioOnly.withHighestBitrate();
        streamUrl = streamInfo.url.toString();
        totalSize = streamInfo.size.totalBytes;
      }

      if (streamUrl == null) throw Exception('No stream found');
      // Ensure totalSize is at least estimated if not provided by API
      totalSize ??= 5 * 1024 * 1024; 

      final url = streamUrl;

      final file = File(task.savePath);
      if (await file.exists()) await file.delete();
      
      final raf = await file.open(mode: FileMode.write);
      
      // ESTRATEGIA: Descarga Secuencial por Bloques (Chunking).
      // YouTube estrangula (throttle) la velocidad después de transmitir ~2MB de datos continuos.
      // Solución: Cerramos y abrimos una nueva petición cada 3MB. Esto "engaña"
      // al CDN haciéndole creer que es un cliente buscando por el archivo y mantiene
      // la velocidad de conexión al máximo siempre.
      final int chunkSize = 3 * 1024 * 1024; // 3 MB
      int downloaded = 0;

      while (downloaded < totalSize) {
        if (task.isCancelled) {
          await raf.close();
          throw Exception('Cancelled');
        }

        int end = downloaded + chunkSize - 1;
        if (end >= totalSize) {
          end = totalSize - 1;
        }

        bool success = false;
        int retries = 0;
        
        while (!success && retries < 3) {
          try {
            final response = await _dio.get<ResponseBody>(
              url,
              options: Options(
                responseType: ResponseType.stream,
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                headers: {
                  'Range': 'bytes=$downloaded-$end',
                  // Usamos un user-agent genérico para no levantar sospechas
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                  'Referer': 'https://www.youtube.com/',
                },
              ),
            );

            await for (final chunk in response.data!.stream) {
              if (task.isCancelled) throw Exception('Cancelled');
              raf.writeFromSync(chunk);
              downloaded += chunk.length;
              task.onProgress(downloaded, totalSize);
            }
            success = true;
          } catch (e) {
            retries++;
            debugPrint('[DownloadService] Chunk error at $downloaded, retrying ($retries/3): $e');
            await Future.delayed(Duration(seconds: retries));
          } // Try block
        } // Retry loop
        
        if (!success) {
          await raf.close();
          throw Exception('Failed to download chunk after 3 retries');
        }
      } // Chunk loop

      await raf.close();
      _taskRegistry.remove(task.id);
      task.completer.complete(true);
    } catch (e) {
      debugPrint('[DownloadService] _downloadAndWrite Error: $e');
      _taskRegistry.remove(task.id);
      task.completer.complete(false);
    }
  }
}
