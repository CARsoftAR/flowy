import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../domain/repositories/repositories.dart';
import '../../../../data/datasources/audio_handler.dart';
import '../../../../core/theme/app_theme.dart';

enum RepeatMode { off, one, all }

enum PlayerStatus { idle, loading, playing, paused, error }

class PlayerProvider extends ChangeNotifier {
  final FlowyAudioHandler _handler;
  final MusicRepository _musicRepo;

  PlayerStatus _status = PlayerStatus.idle;
  SongEntity? _currentSong;
  List<ChapterEntity> _chapters = [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isShuffle = false;
  RepeatMode _repeatMode = RepeatMode.off;
  double _playbackSpeed = 1.0;
  String? _errorMessage;
  // Flag para bloquear el stream mientras se ejecuta stop()
  bool _isStopping = false;
  Map<String, dynamic>? _resumeRequest;
  Color _dominantColor = const Color(0xFF1DB954); // Default Spotify Green

  PlayerProvider({
    required FlowyAudioHandler handler,
    required MusicRepository musicRepository,
  })  : _handler = handler,
        _musicRepo = musicRepository {
    // Registrar callback de error del handler para mostrar en la UI
    _handler.onError = (String msg) {
      _status = PlayerStatus.error;
      _errorMessage = msg;
      notifyListeners();
    };
    _subscribeToStreams();
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  PlayerStatus get status => _status;
  SongEntity? get currentSong => _currentSong;
  List<ChapterEntity> get chapters => _chapters;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _status == PlayerStatus.playing;
  bool get isLoading => _status == PlayerStatus.loading;
  bool get isShuffle => _isShuffle;
  RepeatMode get repeatMode => _repeatMode;
  double get playbackSpeed => _playbackSpeed;
  Color get dominantColor => _dominantColor;
  String? get errorMessage => _errorMessage;
  FlowyAudioHandler get handler => _handler;
  bool get hasError => _status == PlayerStatus.error && _errorMessage != null;
  Map<String, dynamic>? get resumeRequest => _resumeRequest;

  double get progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  List<SongEntity> get queue => _handler.currentQueue;
  int get queueIndex => _handler.currentQueueIndex;

  // ── Stream Subscriptions ──────────────────────────────────────────────────

  void _subscribeToStreams() {
    _handler.mediaItem.listen((item) {
      if (item != null && !_isStopping) {
        _duration = item.duration ?? Duration.zero;
        notifyListeners();
      }
    });

    _handler.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _handler.playbackState.listen((state) {
      // Si estamos en proceso de stop, no restaurar el estado desde el stream
      if (_isStopping) return;

      final nextSong = _handler.currentSong;
      if (nextSong?.id != _currentSong?.id) {
        _currentSong = nextSong;
        _updateDominantColor();
      }

      switch (state.processingState) {
        case AudioProcessingState.idle:
          _status = PlayerStatus.idle;
          _currentSong = null; // siempre limpiar al ir a idle
          break;
        case AudioProcessingState.loading:
        case AudioProcessingState.buffering:
          _status = PlayerStatus.loading;
          break;
        case AudioProcessingState.ready:
          _status = state.playing ? PlayerStatus.playing : PlayerStatus.paused;
          if (_errorMessage != null) _errorMessage = null;
          break;
        case AudioProcessingState.completed:
          _status = PlayerStatus.idle;
          break;
        case AudioProcessingState.error:
          _status = PlayerStatus.error;
          _errorMessage ??= 'Error de reproducción desconocido';
          break;
      }
      _playbackSpeed = state.speed;
      notifyListeners();
    });
    
    // Listen for custom events from AudioHandler
    _handler.customEvent.listen((event) {
      if (event is Map<String, dynamic>) {
        if (event['type'] == 'favorite_toggled') {
          notifyListeners();
        } else if (event['type'] == 'request_resume') {
          _resumeRequest = event;
          notifyListeners();
        } else if (event['type'] == 'url_resolved') {
          notifyListeners();
        }
      }
    });
  }

  Future<void> _updateDominantColor() async {
    final song = _currentSong;
    if (song == null) return;
    
    // Reset chapters
    _chapters = [];
    notifyListeners();

    // Parallel fetch: Palette & Metadata
    Future.wait([
      DynamicPaletteService().getDominantColor(song.bestThumbnail).then((color) {
        if (color != null) _dominantColor = color;
      }),
      _fetchChapters(song.id),
    ]).then((_) => notifyListeners());
  }

  Future<void> _fetchChapters(String songId) async {
    final result = await _musicRepo.getVideoDetails(songId);
    result.fold(
      (l) => null,
      (details) {
        final description = details['description'] as String?;
        if (description != null) {
          _chapters = _parseChapters(description);
        }
      },
    );
  }

  List<ChapterEntity> _parseChapters(String description) {
    final chapters = <ChapterEntity>[];
    // Regex for: 00:00, 0:00, 1:23:45, [00:00], (00:00)
    final regex = RegExp(r'(?:\b|\[|\()(\d{1,2}:)?(\d{1,2}):(\d{2})(?:\b|\]|\))\s*(.*)');
    
    for (final line in description.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final hours = match.group(1) != null ? int.parse(match.group(1)!.replaceAll(':', '')) : 0;
        final minutes = int.parse(match.group(2)!);
        final seconds = int.parse(match.group(3)!);
        var title = match.group(4)?.trim() ?? 'Capítulo';
        
        // Remove leading dashes, dots or numbers followed by dots
        title = title.replaceFirst(RegExp(r'^[\s\-\.\:\)]+'), '').trim();
        
        chapters.add(ChapterEntity(
          startTime: Duration(hours: hours, minutes: minutes, seconds: seconds),
          title: title,
        ));
      }
    }
    return chapters;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> playSong(SongEntity song, {List<SongEntity>? queue}) async {
    _status = PlayerStatus.loading;
    _currentSong = song;
    _errorMessage = null;
    notifyListeners();

    await _handler.playSong(song, playQueue: queue);
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  /// Detiene completamente la reproducción y resetea el estado del player
  Future<void> stop() async {
    _isStopping = true; // bloquea el stream durante el stop
    _status = PlayerStatus.idle;
    _currentSong = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _errorMessage = null;
    notifyListeners();
    await _handler.stop();
    _isStopping = false; // desbloquea el stream
  }

  /// Limpia manualmente el mensaje de error (para dismiss desde la UI)
  void clearError() {
    _errorMessage = null;
    if (_status == PlayerStatus.error) {
      _status = PlayerStatus.idle;
    }
    notifyListeners();
  }

  /// Permite a otros componentes reportar errores que deben mostrarse al usuario
  void reportManualError(String message) {
    _status = PlayerStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  void clearResumeRequest() {
    _resumeRequest = null;
    notifyListeners();
  }

  Future<void> skipToNext() => _handler.skipToNext();
  Future<void> skipToPrevious() => _handler.skipToPrevious();
  Future<void> seekTo(Duration position) => _handler.seek(position);

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await _handler.setSpeed(speed);
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void cycleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.one;
        _handler.setRepeatMode(AudioServiceRepeatMode.one);
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.all;
        _handler.setRepeatMode(AudioServiceRepeatMode.all);
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.off;
        _handler.setRepeatMode(AudioServiceRepeatMode.none);
        break;
    }
    notifyListeners();
  }

  List<SongEntity> get currentQueue => _handler.currentQueue;
  int get currentIndex => _handler.currentQueueIndex;

  void moveQueueItem(int oldIndex, int newIndex) {
    _handler.reorderQueue(oldIndex, newIndex);
    notifyListeners();
  }

  Future<void> playAtIndex(int index) => _handler.skipToQueueItem(index);

  @override
  void dispose() {
    _handler.onError = null;
    _handler.dispose();
    super.dispose();
  }
}
