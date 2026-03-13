import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

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
      final manifest = await _yt.videos.streamsClient.getManifest(
        task.id,
        ytClients: [YoutubeApiClient.androidVr, YoutubeApiClient.ios],
      );
      final streamInfo = manifest.audioOnly.withHighestBitrate();
      if (streamInfo == null) throw Exception('No stream');

      final url = streamInfo.url.toString();
      final totalSize = streamInfo.size.totalBytes;

      final receivePort = ReceivePort();
      
      // Listener de progreso ANTES de lanzar el Isolate
      receivePort.listen((message) {
        if (message is int) {
          task.onProgress(message, totalSize);
        }
      });

      final isolateResult = await Isolate.run(() => _executeIsolatedDownload(
        url: url,
        savePath: task.savePath,
        totalSize: totalSize,
        progressPort: receivePort.sendPort,
      ));

      _taskRegistry.remove(task.id);
      task.completer.complete(isolateResult);
      receivePort.close();
    } catch (e) {
      debugPrint('[DownloadService] _downloadAndWrite Error: $e');
      _taskRegistry.remove(task.id);
      task.completer.complete(false);
    }
  }

  // REESCRITURA TOTAL: Motor de descarga optimizado para HI-FI
  static Future<bool> _executeIsolatedDownload({
    required String url,
    required String savePath,
    required int totalSize,
    required SendPort progressPort,
  }) async {
    final dio = Dio();
    // Configurar cliente persistente (Keep-Alive)
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.idleTimeout = const Duration(seconds: 30);
      client.connectionTimeout = const Duration(seconds: 15);
      return client;
    };

    RandomAccessFile? raf;
    try {
      final file = File(savePath);
      if (await file.exists()) await file.delete();
      raf = await file.open(mode: FileMode.write);
      await raf.truncate(totalSize);

      const int connections = 8;
      final int chunkSize = totalSize ~/ connections;
      final List<Future> pool = [];
      final Map<int, int> progressMap = {};
      
      int lastReportedProgress = 0;

      for (int i = 0; i < connections; i++) {
        final start = i * chunkSize;
        final end = (i == connections - 1) ? totalSize - 1 : (start + chunkSize - 1);
        progressMap[i] = 0;

        pool.add(_downloadChunkIsolated(
          dio: dio,
          url: url,
          start: start,
          end: end,
          raf: raf,
          onProgress: (received) {
            progressMap[i] = received;
            int totalReceived = 0;
            progressMap.forEach((_, v) => totalReceived += v);
            
            // Throttle progress updates to avoid saturation
            if (totalReceived - lastReportedProgress > 65536) { 
              progressPort.send(totalReceived);
              lastReportedProgress = totalReceived;
            }
          },
        ));
      }

      await Future.wait(pool);
      progressPort.send(totalSize);
      await raf.close();
      dio.close();
      return true;
    } catch (e) {
      if (raf != null) await raf.close();
      return false;
    }
  }

  static Future<void> _downloadChunkIsolated({
    required Dio dio,
    required String url,
    required int start,
    required int end,
    required RandomAccessFile raf,
    required Function(int) onProgress,
  }) async {
    final response = await dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Range': 'bytes=$start-$end',
          'User-Agent': 'com.google.android.youtube/19.16.36 (Linux; U; Android 14; en_US) Screen/1.0',
          'Referer': 'https://www.youtube.com/',
          // INSTRUCCIÓN: Accept-Encoding identity para evitar overhead de descompresión
          'Accept-Encoding': 'identity', 
          'Accept': '*/*',
        },
      ),
    );

    int received = 0;
    // INSTRUCCIÓN: Buffer de 64KB (65536 bytes)
    await for (final List<int> chunk in response.data!.stream) {
      // La escritura síncrona en offset es segura dentro del mismo Isolate
      // ya que no hay concurrencia de hilos reales en el modelo de Dart/Isolate
      // para una sola instancia de RandomAccessFile operando sincrónicamente.
      raf.setPositionSync(start + received);
      raf.writeFromSync(chunk);

      received += chunk.length;
      onProgress(received);
    }
  }

}
