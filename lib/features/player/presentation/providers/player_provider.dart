import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../data/datasources/audio_handler.dart';

enum RepeatMode { off, one, all }

enum PlayerStatus { idle, loading, playing, paused, error }

class PlayerProvider extends ChangeNotifier {
  final FlowyAudioHandler _handler;

  PlayerStatus _status = PlayerStatus.idle;
  SongEntity? _currentSong;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isShuffle = false;
  RepeatMode _repeatMode = RepeatMode.off;
  String? _errorMessage;
  // Flag para bloquear el stream mientras se ejecuta stop()
  bool _isStopping = false;

  PlayerProvider({required FlowyAudioHandler handler}) : _handler = handler {
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
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _status == PlayerStatus.playing;
  bool get isLoading => _status == PlayerStatus.loading;
  bool get isShuffle => _isShuffle;
  RepeatMode get repeatMode => _repeatMode;
  String? get errorMessage => _errorMessage;
  FlowyAudioHandler get handler => _handler;
  bool get hasError => _status == PlayerStatus.error && _errorMessage != null;

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

      _currentSong = _handler.currentSong;

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
      notifyListeners();
    });
    
    // Listen for custom events from AudioHandler (e.g., favorite toggled from notification)
    _handler.customEvent.listen((event) {
      if (event is Map && event['type'] == 'favorite_toggled') {
        // We can't reach LibraryProvider directly here easy, 
        // but we can notify the UI layer to refresh.
        notifyListeners();
      }
    });
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

  Future<void> skipToNext() => _handler.skipToNext();
  Future<void> skipToPrevious() => _handler.skipToPrevious();
  Future<void> seekTo(Duration position) => _handler.seek(position);

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
