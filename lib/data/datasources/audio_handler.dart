import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FlowyAudioHandler — v4 (Fix "Bad state: addStream + pipe conflict")
//
// CAUSA DEL NUEVO CRASH:
//   Al crear un AudioPlayer fresco y llamar _attachListeners() de nuevo,
//   el código anterior hacía .pipe(playbackState). playbackState es un
//   BehaviorSubject. Dart no permite dos addStream() simultáneos sobre el
//   mismo StreamController → "Bad state: You cannot add items while items
//   are being added from addStream".
//
// FIX:
//  • Se reemplaza .pipe() por .listen() manual que llama playbackState.add().
//  • Se mantiene una lista de StreamSubscriptions activas que se cancela
//    ANTES de crear el nuevo player → nunca hay listeners duplicados.
//  • El AudioPlayer se reutiliza entre pistas (NO se crea uno nuevo por pista).
//    setAudioSource() ya reemplaza internamente el source sin necesitar stop().
//  • "Generation token" para cancelar cargas obsoletas sin tocar el player.
// ─────────────────────────────────────────────────────────────────────────────

typedef OnPlayerError = void Function(String message);

class FlowyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final MusicRepository _musicRepo;
  final Logger _log;

  /// Callback que la UI registra para mostrar mensajes de error amistosos
  OnPlayerError? onError;

  List<SongEntity> _queue = [];
  int _currentIndex = 0;

  // Generation token — cada nueva carga incrementa este valor.
  // Una carga compara su token al final para saber si fue superseded.
  int _loadGeneration = 0;

  // UN SOLO player que se reutiliza. setAudioSource() maneja el reemplazo.
  late final AudioPlayer _player;

  // Subscripciones activas a los streams del player
  final List<StreamSubscription> _subs = [];

  // Cache de URLs resueltas (videoId → URL de stream)
  final Map<String, String> _urlCache = {};

  FlowyAudioHandler({
    required MusicRepository musicRepository,
    Logger? logger,
    this.onError,
  })  : _musicRepo = musicRepository,
        _log = logger ?? Logger(printer: PrettyPrinter(methodCount: 4)) {
    _player = AudioPlayer();
    _attachListeners();
  }

  // ── Listeners (UN SOLO attach, sin pipe()) ────────────────────────────────

  void _attachListeners() {
    // Usar listen() en vez de pipe() para evitar el conflicto de addStream
    _subs.add(
      _player.playbackEventStream.listen(
        (event) {
          try {
            playbackState.add(_buildPlaybackState(event));
          } catch (e) {
            _log.w('[AudioHandler] playbackState.add ignorado: $e');
          }
        },
        onError: (e) => _log.w('[AudioHandler] playbackEventStream error: $e'),
      ),
    );

    // Auto-avance al completar pista
    _subs.add(
      _player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) {
          _log.d('[AudioHandler] Pista completada → next');
          unawaited(_advanceToNext());
        }
      }),
    );
  }

  void _cancelListeners() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _log.d('[AudioHandler] Subscripciones canceladas');
  }

  Future<void> _advanceToNext() async {
    // No avanzar si la cola fue limpiada (p.ej. después de stop())
    if (_queue.isEmpty) return;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      await _loadAndPlay(_currentIndex);
    } else {
      _log.d('[AudioHandler] Fin de cola');
    }
  }

  PlaybackState _buildPlaybackState(PlaybackEvent event) {
    final playing = _player.playing;
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
    );
  }

  // ── API pública ────────────────────────────────────────────────────────────

  Future<void> playSong(SongEntity song, {List<SongEntity>? playQueue}) async {
    _queue = playQueue ?? [song];
    final idx = _queue.indexWhere((s) => s.id == song.id);
    _currentIndex = idx < 0 ? 0 : idx;

    _updateQueueMetadata();
    await _loadAndPlay(_currentIndex);
    _preloadUpcoming();
  }

  // ── BaseAudioHandler overrides ─────────────────────────────────────────────

  @override
  Future<void> play() async => _player.play();

  @override
  Future<void> pause() async => _player.pause();

  @override
  Future<void> stop() async {
    // Incrementar generación cancela cualquier carga en vuelo
    _loadGeneration++;
    // Limpiar la cola → currentSong retornará null → mini player desaparece
    _queue = [];
    _currentIndex = 0;
    // Llamar _player.stop() (no pause) para ir a ProcessingState.idle
    // Esto es seguro aquí porque no hay setAudioSource() concurrente:
    // el usuario explícitamente detuvo la reproducción.
    try {
      await _player.stop();
    } catch (e) {
      _log.w('[AudioHandler] stop() error (ignorado): $e');
    }
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_currentIndex < _queue.length - 1) {
      await skipToQueueItem(_currentIndex + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
    } else if (_currentIndex > 0) {
      await skipToQueueItem(_currentIndex - 1);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _queue.length) {
      _currentIndex = index;
      await _loadAndPlay(_currentIndex);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
      case AudioServiceRepeatMode.all:
        await _player.setLoopMode(LoopMode.all);
      default:
        await _player.setLoopMode(LoopMode.off);
    }
    await super.setRepeatMode(repeatMode);
  }

  // ── Carga principal ────────────────────────────────────────────────────────

  Future<void> _loadAndPlay(int index) async {
    final myGeneration = ++_loadGeneration;
    final song = _queue[index];

    _log.i('[AudioHandler] Carga #$myGeneration › "${song.title}" (id=${song.id})');
    _updateCurrentMediaItem(song);

    // ── PASO 1: Pausar reproducción actual de forma segura ────────────────
    // Pausamos (NO stop) para no disparar el bug del Future circular.
    try {
      if (_player.playing) {
        await _player.pause();
        _log.d('[AudioHandler] Player pausado antes de nueva carga');
      }
    } catch (e) {
      _log.w('[AudioHandler] Error al pausar (ignorado): $e');
    }

    // ── PASO 2: Resolver URL ──────────────────────────────────────────────
    final String streamUrl;
    try {
      if (_urlCache.containsKey(song.id)) {
        streamUrl = _urlCache[song.id]!;
        _log.d('[AudioHandler] URL desde cache');
      } else {
        _log.d('[AudioHandler] Solicitando URL a YouTube…');
        final result = await _musicRepo
            .getStreamUrl(song.id)
            .timeout(const Duration(seconds: 20));
        streamUrl = result.fold(
          (failure) {
            _log.e('[AudioHandler] getStreamUrl falló: ${failure.message}');
            throw Exception(failure.message);
          },
          (url) => url,
        );
        _urlCache[song.id] = streamUrl;
        _log.d('[AudioHandler] URL resuelta correctamente');
      }
    } on TimeoutException {
      _log.e('[AudioHandler] Timeout resolviendo URL para "${song.title}"');
      _notifyError('Sin conexión con YouTube. Verifica tu internet.');
      _tryNext(myGeneration, index);
      return;
    } catch (e) {
      _log.e('[AudioHandler] Error resolviendo URL: $e');
      _notifyError('No se pudo cargar "${song.title}".');
      _tryNext(myGeneration, index);
      return;
    }

    // ── PASO 3: Verificar que seguimos siendo la carga vigente ────────────
    if (myGeneration != _loadGeneration) {
      _log.w('[AudioHandler] Carga #$myGeneration superada, abortando');
      return;
    }

    // ── PASO 4: Cargar fuente en el player ────────────────────────────────
    // setAudioSource() reemplaza el source sin necesitar stop() previo.
    // Esto evita el bug "Cannot complete a future with itself".
    try {
      _log.d('[AudioHandler] Llamando setAudioSource…');
      await _player
          .setAudioSource(
            AudioSource.uri(
              Uri.parse(streamUrl),
              tag: _buildMediaItem(song),
            ),
            preload: true,
          )
          .timeout(const Duration(seconds: 20));
      _log.d('[AudioHandler] setAudioSource OK');
    } on TimeoutException {
      _log.e('[AudioHandler] Timeout en setAudioSource para "${song.title}"');
      _notifyError('El audio tardó demasiado en cargar. Saltando…');
      _tryNext(myGeneration, index);
      return;
    } on PlayerException catch (e) {
      _log.e('[AudioHandler] PlayerException: code=${e.code} msg=${e.message}');
      _notifyError('Error de reproducción: ${e.message ?? "desconocido"}');
      _tryNext(myGeneration, index);
      return;
    } catch (e, st) {
      _log.e('[AudioHandler] Error inesperado en setAudioSource', error: e, stackTrace: st);
      _notifyError('Error técnico al cargar audio. Saltando…');
      _tryNext(myGeneration, index);
      return;
    }

    // ── PASO 5: Play ──────────────────────────────────────────────────────
    if (myGeneration != _loadGeneration) {
      _log.w('[AudioHandler] Generación cambió antes de play(), cancelando');
      return;
    }

    _log.i('[AudioHandler] ▶ Reproduciendo "${song.title}"');
    unawaited(_player.play());
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _tryNext(int generation, int failedIndex) {
    if (generation != _loadGeneration) return;
    if (failedIndex < _queue.length - 1) {
      _log.d('[AudioHandler] Saltando al siguiente tras error');
      Future.delayed(const Duration(milliseconds: 800), () {
        if (generation == _loadGeneration) {
          _currentIndex = failedIndex + 1;
          unawaited(_loadAndPlay(_currentIndex));
        }
      });
    }
  }

  void _notifyError(String message) {
    _log.w('[AudioHandler] Error UI: $message');
    onError?.call(message);
  }

  void _updateCurrentMediaItem(SongEntity song) {
    mediaItem.add(_buildMediaItem(song));
  }

  MediaItem _buildMediaItem(SongEntity song) {
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artUri: song.bestThumbnail.isNotEmpty
          ? Uri.tryParse(song.bestThumbnail)
          : null,
      extras: const {'source': 'youtube'},
    );
  }

  void _updateQueueMetadata() {
    queue.add(_queue.map(_buildMediaItem).toList());
  }

  void _preloadUpcoming() {
    for (int i = 1; i <= 2; i++) {
      final idx = _currentIndex + i;
      if (idx < _queue.length) {
        final nextSong = _queue[idx];
        if (!_urlCache.containsKey(nextSong.id)) {
          _log.d('[AudioHandler] Pre-cargando URL para "${nextSong.title}"');
          _musicRepo.getStreamUrl(nextSong.id).then((result) {
            result.fold(
              (f) => _log.w('[AudioHandler] Pre-carga falló "${nextSong.title}": ${f.message}'),
              (url) {
                _urlCache[nextSong.id] = url;
                _log.d('[AudioHandler] Pre-caché OK: "${nextSong.title}"');
              },
            );
          });
        }
      }
    }
  }

  // ── Streams públicos ──────────────────────────────────────────────────────

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<double> get volumeStream => _player.volumeStream;
  Duration get position => _player.position;
  bool get isPlaying => _player.playing;
  SongEntity? get currentSong =>
      _queue.isNotEmpty ? _queue[_currentIndex] : null;
  List<SongEntity> get currentQueue => List.unmodifiable(_queue);
  int get currentQueueIndex => _currentIndex;

  Future<void> dispose() async {
    _loadGeneration++; // cancela cargas en vuelo
    _cancelListeners();
    await _player.dispose();
  }
}
