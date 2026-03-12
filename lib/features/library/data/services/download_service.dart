// ─────────────────────────────────────────────────────────────────────────────
// DownloadService — Servicio de descarga aislado con cola secuencial
//
// Política:
//  - Una sola descarga activa a la vez (cola FIFO estricta)
//  - Usa YoutubeExplode directamente para manejar el descifrado de 'n' (velocidad)
//  - Escritura con IOSink + flush() + close() explícito antes de señalar "done"
//  - No toca ningún componente de UI
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:collection';
import 'dart:io';
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
  
  DownloadService(this._yt);

  // ── Cola FIFO de tareas ────────────────────────────────────────────────────
  final Queue<_DownloadTask> _queue = Queue();
  final Map<String, _DownloadTask> _taskRegistry = {};
  bool _isProcessing = false;

  /// Encola una descarga y devuelve un Future<bool> que completa
  /// cuando el archivo está en disco y cerrado.
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

  Future<void> _downloadAndWrite(_DownloadTask task) async {
    IOSink? sink;
    File? file;

    try {
      debugPrint('[DownloadService] [${task.id}] Iniciando descarga optimizada...');
      
      // 1. Obtener el manifest justo antes de descargar
      final manifest = await _yt.videos.streamsClient.getManifest(task.id);
      final streamInfo = manifest.audioOnly.withHighestBitrate();
      
      if (streamInfo == null) {
        throw Exception('No audio stream found for ${task.id}');
      }

      final total = streamInfo.size.totalBytes;
      
      // 2. Preparar archivo
      file = File(task.savePath);
      sink = file.openWrite(mode: FileMode.writeOnly);

      // 3. Obtener el stream usando YoutubeExplode (esto maneja el descifrado de parámetros de velocidad)
      final stream = _yt.videos.streamsClient.get(streamInfo);

      int received = 0;
      DateTime lastProgress = DateTime.now();

      await for (final List<int> chunk in stream) {
        if (task.isCancelled) {
          throw const _CancelledException();
        }

        sink.add(chunk);
        received += chunk.length;

        final now = DateTime.now();
        if (now.difference(lastProgress).inMilliseconds > 200) {
          task.onProgress(received, total);
          lastProgress = now;
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      task.onProgress(received, total);
      debugPrint('[DownloadService] [${task.id}] ✅ Descarga exitosa.');
    } on _CancelledException {
      if (sink != null) await sink.close();
      if (file != null && await file.exists()) await file.delete();
    } catch (e) {
      if (sink != null) await sink.close();
      if (file != null && await file.exists()) await file.delete();
      rethrow;
    }
  }
}

class _CancelledException implements Exception {
  const _CancelledException();
}
