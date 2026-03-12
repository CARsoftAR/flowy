// ─────────────────────────────────────────────────────────────────────────────
// DownloadService — Servicio de descarga aislado con cola secuencial
//
// Política:
//  - Una sola descarga activa a la vez (cola FIFO estricta)
//  - Usa dart:io HttpClient directamente (sin Dio) para control total del stream
//  - Escritura con IOSink + flush() + close() explícito antes de señalar "done"
//  - Logging diagnóstico tipado (SocketException, HttpException, FileSystemException)
//  - No toca ningún componente de UI
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

typedef DownloadProgressCallback = void Function(int received, int total);

/// Tarea interna del queue
class _DownloadTask {
  final String id;
  final String url;
  final String savePath;
  final DownloadProgressCallback onProgress;
  final Completer<bool> completer = Completer<bool>();
  bool _cancelled = false;

  _DownloadTask({
    required this.id,
    required this.url,
    required this.savePath,
    required this.onProgress,
  });

  void cancel() => _cancelled = true;
  bool get isCancelled => _cancelled;
}

class DownloadService {
  static const String _tag = '[DownloadService]';

  // User-Agent que coincide con la app Android de YouTube
  // (es el que generó la URL firmada, deben coincidir)
  static const String _ytAndroidAgent =
      'com.google.android.youtube/17.36.4 (Linux; U; Android 12; GB) gzip';

  static const Duration _connectionTimeout = Duration(seconds: 30);
  static const Duration _receiveChunkTimeout = Duration(seconds: 30);

  // ── Cola FIFO de tareas ────────────────────────────────────────────────────
  final Queue<_DownloadTask> _queue = Queue();
  final Map<String, _DownloadTask> _taskRegistry = {};
  bool _isProcessing = false;

  /// Encola una descarga y devuelve un Future<bool> que completa
  /// cuando el archivo está en disco y cerrado.
  Future<bool> enqueue({
    required String id,
    required String url,
    required String savePath,
    required DownloadProgressCallback onProgress,
  }) {
    // Si ya hay una tarea con el mismo id, devolverla
    if (_taskRegistry.containsKey(id)) {
      return _taskRegistry[id]!.completer.future;
    }

    final task = _DownloadTask(
      id: id,
      url: url,
      savePath: savePath,
      onProgress: onProgress,
    );

    _taskRegistry[id] = task;
    _queue.addLast(task);
    _kickQueue();
    return task.completer.future;
  }

  /// Cancela una descarga en curso o pendiente
  void cancel(String id) {
    _taskRegistry[id]?.cancel();
  }

  bool get isProcessing => _isProcessing;
  bool isPending(String id) => _taskRegistry.containsKey(id);

  // ── Procesador de cola ─────────────────────────────────────────────────────
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
      // Esperar al próximo frame para asegurar que el archivo fue
      // cerrado antes de iniciar la siguiente descarga
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
      _logError(task.id, e, st);
      task.completer.complete(false);
    }
  }

  // ── Descarga + Escritura ──────────────────────────────────────────────────
  Future<void> _downloadAndWrite(_DownloadTask task) async {
    // Instancia limpia por descarga — no reutilizar el pool de conexiones
    final client = HttpClient()
      ..connectionTimeout = _connectionTimeout
      ..idleTimeout =
          const Duration(seconds: 3) // Cierra idle sockets rápido
      ..userAgent = _ytAndroidAgent
      ..autoUncompress = false; // Manejar compresión manualmente

    IOSink? sink;
    File?   file;

    try {
      final uri = Uri.parse(task.url);

      // ── Phase 1: Conexión ────────────────────────────────────────────────
      debugPrint('$_tag [${task.id}] Connecting to CDN...');
      final request = await client
          .getUrl(uri)
          .timeout(_connectionTimeout, onTimeout: () {
        throw TimeoutException(
            'Connection timeout after ${_connectionTimeout.inSeconds}s',
            _connectionTimeout);
      });

      // SIN headers adicionales — URL pre-firmada, no necesita Referer/Origin
      request.headers.set(HttpHeaders.connectionHeader, 'close');

      // ── Phase 2: Respuesta ────────────────────────────────────────────────
      final response = await request.close().timeout(
        _connectionTimeout,
        onTimeout: () => throw TimeoutException(
            'Response timeout', _connectionTimeout),
      );

      if (response.statusCode != 200 && response.statusCode != 206) {
        await response.drain<void>(); // liberar la conexión
        throw HttpException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          uri: uri,
        );
      }

      final total = response.contentLength; // -1 si no viene Content-Length
      debugPrint(
          '$_tag [${task.id}] Connected. Size: ${total > 0 ? '${(total / 1048576).toStringAsFixed(1)} MB' : 'unknown'}');

      // ── Phase 3: Escritura en disco con IOSink ────────────────────────────
      file = File(task.savePath);
      sink = file.openWrite(mode: FileMode.writeOnly);

      int received = 0;
      DateTime lastProgress = DateTime.now();

      await for (final List<int> chunk in response) {
        // Chequear cancelación en cada chunk
        if (task.isCancelled) {
          throw const _CancelledException();
        }

        // Escribir chunk al IOSink (buffered, async, no bloquea el main thread)
        sink.add(chunk);
        received += chunk.length;

        // Throttle de progreso: no más de 10 updates/segundo
        final now = DateTime.now();
        if (now.difference(lastProgress).inMilliseconds > 100) {
          task.onProgress(received, total);
          lastProgress = now;
        }

        // Watchdog por chunk: si pasa mucho tiempo sin datos → timeout
        // (la lógica de timeout del HttpClient ya cubre el connection level)
      }

      // ── Phase 4: Flush y CLOSE antes de señalar "done" ──────────────────
      // Esta es la parte crítica: esperar flush() + close() explícito
      await sink.flush();
      await sink.close();
      sink = null; // marcar como cerrado para el finally

      // Reporte final de progreso
      task.onProgress(received, total > 0 ? total : received);

      // ── Phase 5: Verificación de integridad ──────────────────────────────
      final writtenSize = await file.length();
      if (writtenSize == 0) {
        throw FileSystemException(
            'File written but is empty (0 bytes)', task.savePath);
      }

      debugPrint(
          '$_tag [${task.id}] ✅ Done. Written: ${(writtenSize / 1048576).toStringAsFixed(2)} MB | Path: ${task.savePath}');
    } on _CancelledException {
      // Limpieza de archivo parcial sin re-lanzar el error
      sink?.close().catchError((_) {});
      sink = null;
      if (file != null && await file.exists()) {
        await file.delete().catchError((_) {});
      }
      debugPrint('$_tag [${task.id}] Cancelled — partial file removed.');
    } catch (_) {
      // Limpieza de archivo parcial
      if (sink != null) {
        try {
          await sink.flush();
        } catch (_) {}
        try {
          await sink.close();
        } catch (_) {}
        sink = null;
      }
      if (file != null && await file.exists()) {
        await file.delete().catchError((_) {});
      }
      rethrow;
    } finally {
      // Forzar cierre del cliente HTTP — libera el pool de conexiones
      client.close(force: true);
      // Si sink quedó abierto por alguna razón, cerrarlo
      try {
        await sink?.close();
      } catch (_) {}
    }
  }

  // ── Logging Diagnóstico ───────────────────────────────────────────────────
  void _logError(String id, Object error, StackTrace st) {
    if (error is _CancelledException) {
      // Ya logueado en _downloadAndWrite
      return;
    } else if (error is SocketException) {
      debugPrint(
          '$_tag [$id] SocketException: "${error.message}" '
          '| Host: ${error.address?.host} Port: ${error.port} '
          '| OS Error Code: ${error.osError?.errorCode} — ${error.osError?.message}');
    } else if (error is HttpException) {
      debugPrint('$_tag [$id] HttpException: "${error.message}"');
    } else if (error is FileSystemException) {
      debugPrint(
          '$_tag [$id] FileSystemException: "${error.message}" '
          '| Path: "${error.path}" '
          '| OS Error: ${error.osError?.errorCode} — ${error.osError?.message}');
    } else if (error is TimeoutException) {
      debugPrint(
          '$_tag [$id] TimeoutException: "${error.message}" '
          'after ${error.duration?.inSeconds ?? '?'}s');
    } else if (error is TlsException) {
      debugPrint('$_tag [$id] TlsException (SSL): $error');
    } else {
      debugPrint('$_tag [$id] ❌ Unexpected error: $error');
      debugPrint('$_tag Stack:\n$st');
    }
  }
}

class _CancelledException implements Exception {
  const _CancelledException();
  @override
  String toString() => 'DownloadService: Download cancelled by user';
}
