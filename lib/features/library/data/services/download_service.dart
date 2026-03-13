import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

typedef DownloadProgressCallback = void Function(int received, int total);

/// Tarea interna del queue
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

  // ── Cola FIFO de tareas ────────────────────────────────────────────────────
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

    final task = _DownloadTask(
      id: id,
      savePath: savePath,
      onProgress: onProgress,
    );

    _taskRegistry[id] = task;
    _queue.addLast(task);
    _kickQueue();
    return task.completer.future;
  }

  void cancel(String id) {
    _taskRegistry[id]?.cancel();
  }

  bool get isProcessing => _isProcessing;
  bool isPending(String id) => _taskRegistry.containsKey(id);

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

    _run(task).then((_) {
      Future.microtask(_processNext);
    });
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
      debugPrint('[DownloadService] Error en tarea ${task.id}: $e\n$st');
      task.completer.complete(false);
    }
  }

  /// MEGA SPEED DOWNLOAD: Usa múltiples conexiones paralelas (Range)
  /// Esto bypassa el "throttling" de YouTube por conexión individual.
  Future<void> _downloadAndWrite(_DownloadTask task) async {
    RandomAccessFile? raf;
    File? file;

    try {
      debugPrint('[DownloadService] [${task.id}] Extrayendo manifest ultra-speed...');
      
      // 1. Obtener manifest con clientes móviles (iOS/AndroidVr suelen ser más rápidos)
      final manifest = await _yt.videos.streamsClient.getManifest(
        task.id,
        ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidVr],
      );
      
      final streamInfo = manifest.audioOnly.withHighestBitrate();
      if (streamInfo == null) throw Exception('No audio stream for ${task.id}');

      final String url = streamInfo.url.toString();
      final int totalSize = streamInfo.size.totalBytes;
      
      file = File(task.savePath);
      if (await file.exists()) await file.delete();
      raf = await file.open(mode: FileMode.write);
      // Pre-asignar espacio para evitar fragmentación
      await raf.truncate(totalSize);

      // 2. Definir chunks (3 conexiones paralelas suelen ser el "sweet spot" para YouTube)
      const int connections = 3;
      final int chunkSize = totalSize ~/ connections;
      
      int globalReceived = 0;
      final Map<int, int> chunkProgress = {};
      final progressController = StreamController<void>.broadcast();

      // Listener para progreso unificado
      final progressSub = progressController.stream.listen((_) {
        int currentTotal = 0;
        chunkProgress.forEach((_, val) => currentTotal += val);
        task.onProgress(currentTotal, totalSize);
      });

      final List<Future> downloadPool = [];

      for (int i = 0; i < connections; i++) {
        final int start = i * chunkSize;
        final int end = (i == connections - 1) ? totalSize - 1 : (start + chunkSize - 1);
        
        chunkProgress[i] = 0;

        downloadPool.add(_downloadChunk(
          url: url,
          start: start,
          end: end,
          task: task,
          raf: raf,
          onChunkProgress: (received) {
            chunkProgress[i] = received;
            progressController.add(null);
          },
        ));
      }

      await Future.wait(downloadPool);
      await progressSub.cancel();
      await progressController.close();
      await raf.close();
      raf = null;

      debugPrint('[DownloadService] [${task.id}] ✅ Descarga paralela completada.');
    } on _CancelledException {
      if (raf != null) await raf.close();
      if (file != null && await file.exists()) await file.delete();
    } catch (e) {
      if (raf != null) await raf.close();
      if (file != null && await file.exists()) await file.delete();
      rethrow;
    }
  }

  Future<void> _downloadChunk({
    required String url,
    required int start,
    required int end,
    required _DownloadTask task,
    required RandomAccessFile raf,
    required Function(int) onChunkProgress,
  }) async {
    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Range': 'bytes=$start-$end',
          'User-Agent': 'com.google.android.youtube/19.16.36 (Linux; U; Android 14; en_US) Screen/1.0',
        },
      ),
    );

    int receivedInChunk = 0;
    await for (final List<int> chunk in response.data!.stream) {
      if (task.isCancelled) throw const _CancelledException();

      // Escritura atómica en el offset correcto
      // Nota: raf no es thread-safe para operaciones asíncronas concurrentes, 
      // pero aquí estamos usando una sola instancia. Synchronized writing es necesario.
      synchronized(raf, () async {
        await raf.setPosition(start + receivedInChunk);
        await raf.writeFrom(chunk);
      });

      receivedInChunk += chunk.length;
      onChunkProgress(receivedInChunk);
    }
  }

  // Simple mutex para RandomAccessFile
  final Map<RandomAccessFile, Completer<void>?> _locks = {};
  Future<void> synchronized(RandomAccessFile raf, Future<void> Function() action) async {
    while (_locks[raf] != null) {
      await _locks[raf]!.future;
    }
    final completer = Completer<void>();
    _locks[raf] = completer;
    try {
      await action();
    } finally {
      _locks[raf] = null;
      completer.complete();
    }
  }
}

class _CancelledException implements Exception {
  const _CancelledException();
}
