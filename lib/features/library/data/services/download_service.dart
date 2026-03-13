import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:dio/dio.dart';
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
  final Dio _dio = Dio();
  
  DownloadService(this._yt) {
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(minutes: 5);
  }

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
      _taskRegistry.remove(task.id);
      task.completer.complete(true);
    } catch (e, st) {
      _taskRegistry.remove(task.id);
      debugPrint('[DownloadService] Error: $e');
      task.completer.complete(false);
    }
  }

  Future<void> _downloadAndWrite(_DownloadTask task) async {
    RandomAccessFile? raf;
    File? file;

    try {
      debugPrint('[DownloadService] Extraction: ${task.id}');
      
      // PRIORIDAD: AndroidVr > iOS (Son los que menos throttling tienen)
      final manifest = await _yt.videos.streamsClient.getManifest(
        task.id,
        ytClients: [YoutubeApiClient.androidVr, YoutubeApiClient.ios],
      );
      
      final streamInfo = manifest.audioOnly.withHighestBitrate();
      if (streamInfo == null) throw Exception('No stream');

      final String url = streamInfo.url.toString();
      final int totalSize = streamInfo.size.totalBytes;
      
      file = File(task.savePath);
      if (await file.exists()) await file.delete();
      raf = await file.open(mode: FileMode.write);
      await raf.truncate(totalSize);

      // 8 CONEXIONES PARALELAS (Ruptura de throttling por volumen)
      const int connections = 8;
      final int chunkSize = totalSize ~/ connections;
      
      final Map<int, int> progressMap = {};
      final progressController = StreamController<void>.broadcast();

      final sub = progressController.stream.listen((_) {
        int current = 0;
        progressMap.forEach((_, v) => current += v);
        task.onProgress(current, totalSize);
      });

      final List<Future> pool = [];
      for (int i = 0; i < connections; i++) {
        final int start = i * chunkSize;
        final int end = (i == connections - 1) ? totalSize - 1 : (start + chunkSize - 1);
        progressMap[i] = 0;

        pool.add(_downloadChunk(
          url: url,
          start: start,
          end: end,
          task: task,
          raf: raf,
          onProgress: (v) {
            progressMap[i] = v;
            progressController.add(null);
          },
        ));
      }

      await Future.wait(pool);
      await sub.cancel();
      await progressController.close();
      await raf.close();
      
      debugPrint('[DownloadService] [${task.id}] ✅ Done.');
    } catch (e) {
      if (raf != null) await raf.close();
      rethrow;
    }
  }

  Future<void> _downloadChunk({
    required String url,
    required int start,
    required int end,
    required _DownloadTask task,
    required RandomAccessFile raf,
    required Function(int) onProgress,
  }) async {
    // Cabeceras de mimetismo oficial para engañar al CDN de Google
    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Range': 'bytes=$start-$end',
          'User-Agent': 'com.google.android.youtube/19.16.36 (Linux; U; Android 14; en_US) Screen/1.0',
          'Referer': 'https://www.youtube.com/',
          'Origin': 'https://www.youtube.com',
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
          'X-YouTube-Client-Name': '3', 
          'X-YouTube-Client-Version': '19.16.36',
        },
      ),
    );

    int received = 0;
    await for (final List<int> chunk in response.data!.stream) {
      if (task.isCancelled) throw Exception('Cancelled');
      
      // Escritura síncrona en el offset exacto - mucho más rápido que IOSink para paralelismo
      // raf.writeFromSync es thread-safe a nivel de puntero de archivo si nos posicionamos antes.
      synchronizedWrite(raf, start + received, chunk);

      received += chunk.length;
      onProgress(received);
    }
  }

  // Mutex optimizado para escrituras críticas
  bool _isWriting = false;
  void synchronizedWrite(RandomAccessFile raf, int position, List<int> data) {
    // En Dart, el código asíncrono no se interrumpe entre sí en el mismo isolate
    // a menos que haya un 'await'. writeFromSync es instantáneo y bloqueante pero
    // seguro para la integridad del archivo en este contexto.
    raf.setPositionSync(position);
    raf.writeFromSync(data);
  }
}
