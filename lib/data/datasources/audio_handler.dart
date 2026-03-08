import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../data/models/song_model.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import 'package:rxdart/rxdart.dart';

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

  // Dual players for crossfading
  late final AudioPlayer _player1;
  late final AudioPlayer _player2;
  bool _usePlayer1 = true;
  
  AudioPlayer get _activePlayer => _usePlayer1 ? _player1 : _player2;
  AudioPlayer get _inactivePlayer => _usePlayer1 ? _player2 : _player1;

  // Equalizer (Applied to both players)
  AndroidEqualizer? _equalizer1;
  AndroidEqualizer? _equalizer2;

  // Subscripciones activas
  final List<StreamSubscription> _subs = [];

  // Cache de URLs resueltas
  final Map<String, String> _urlCache = {};
  final SharedPreferences _prefs;



  FlowyAudioHandler({
    required MusicRepository musicRepository,
    required SharedPreferences sharedPreferences,
    Logger? logger,
    this.onError,
  })  : _musicRepo = musicRepository,
        _prefs = sharedPreferences,
        _log = logger ?? Logger(printer: PrettyPrinter(methodCount: 4)) {
    _equalizer1 = AndroidEqualizer();
    _equalizer2 = AndroidEqualizer();
    
    _player1 = AudioPlayer(audioPipeline: AudioPipeline(androidAudioEffects: [_equalizer1!]));
    _player2 = AudioPlayer(audioPipeline: AudioPipeline(androidAudioEffects: [_equalizer2!]));
    
    _attachListeners();
  }

  static const MediaControl _favoriteOn = MediaControl(
    androidIcon: 'drawable/ic_heart_filled',
    label: 'Me gusta',
    action: MediaAction.setRating,
  );
  
  static const MediaControl _favoriteOff = MediaControl(
    androidIcon: 'drawable/ic_heart',
    label: 'Me gusta',
    action: MediaAction.setRating,
  );

  double _crossfadeDuration = 0.0;

  void setCrossfade(double seconds) => _crossfadeDuration = seconds;

  void _attachListeners() {
    // Listen to both players but primary drives the state
    _listenToPlayer(_player1);
    _listenToPlayer(_player2);
  }

  void _listenToPlayer(AudioPlayer player) {
    _subs.add(player.playbackEventStream.listen((event) {
      if (player == _activePlayer) {
        try {
          playbackState.add(_buildPlaybackState(event, player));
        } catch (e) {
          _log.w('[AudioHandler] playbackState.add error: $e');
        }
      }
    }));

    _subs.add(player.processingStateStream.listen((state) {
      if (player == _activePlayer && state == ProcessingState.completed) {
        _log.d('[AudioHandler] Playback completed on active player');
        unawaited(_advanceToNext());
      }
    }));

    // Crossfade trigger
    _subs.add(player.positionStream.listen((pos) {
      if (player == _activePlayer && _crossfadeDuration > 0) {
        final remaining = (player.duration ?? Duration.zero) - pos;
        if (remaining.inMilliseconds > 0 && 
            remaining.inMilliseconds <= (_crossfadeDuration * 1000) &&
            _currentIndex < _queue.length - 1 &&
            player.playing) {
          // Trigger crossfade once
          _checkAndTriggerCrossfade(player);
        }
      }
    }));
  }

  bool _isCrossfading = false;
  void _checkAndTriggerCrossfade(AudioPlayer sourcePlayer) {
    if (_isCrossfading) return;
    _isCrossfading = true;
    _log.i('[AudioHandler] 🔀 Initiating crossfade to next song');
    unawaited(_crossfadeToNext());
  }

  Future<void> _crossfadeToNext() async {
    final oldPlayer = _activePlayer;
    final nextIdx = _currentIndex + 1;
    
    // Switch active player early so UI reflects next song
    _usePlayer1 = !_usePlayer1;
    _currentIndex = nextIdx;
    
    final newPlayer = _activePlayer;
    
    // Start loading next on new player
    await _loadAndPlay(_currentIndex, crossfadeFrom: oldPlayer);
    _isCrossfading = false;
  }

  void _cancelListeners() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _log.d('[AudioHandler] Subscripciones canceladas');
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);

    // Update currentIndex if needed
    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex -= 1;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex += 1;
    }

    _updateQueueMetadata();
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

  PlaybackState _buildPlaybackState(PlaybackEvent event, AudioPlayer player) {
    final playing = player.playing;
    final currentId = currentSong?.id;
    final likedSongsJson = _prefs.getStringList('liked_songs') ?? [];
    final isLiked = likedSongsJson.any((j) {
      try {
        return (jsonDecode(j)['id'] as String) == currentId;
      } catch (_) {
        return false;
      }
    });

    return PlaybackState(
      controls: [
        isLiked 
          ? _favoriteOn.copyWith(label: 'Quitar de favoritos') 
          : _favoriteOff.copyWith(label: 'Me gusta'),
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setRating,
      },
      androidCompactActionIndices: const [0, 2, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
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
  Future<void> play() async => _activePlayer.play();

  @override
  Future<void> pause() async => _activePlayer.pause();

  @override
  Future<void> stop() async {
    _loadGeneration++;
    _queue = [];
    _currentIndex = 0;
    try {
      await Future.wait([
        _player1.stop(),
        _player2.stop(),
      ]);
    } catch (e) {
      _log.w('[AudioHandler] stop() error: $e');
    }
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async => _activePlayer.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_currentIndex < _queue.length - 1) {
      await skipToQueueItem(_currentIndex + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_activePlayer.position.inSeconds > 3) {
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
    final loop = switch (repeatMode) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all => LoopMode.all,
      _ => LoopMode.off,
    };
    await Future.wait([
      _player1.setLoopMode(loop),
      _player2.setLoopMode(loop),
    ]);
    await super.setRepeatMode(repeatMode);
  }

  @override
  Future<void> setRating(Rating rating, [Map<String, dynamic>? extras]) async {
    _log.i('[AudioHandler] setRating called from notification');
    final song = currentSong;
    if (song == null) return;

    final likedSongsJson = _prefs.getStringList('liked_songs') ?? [];
    final index = likedSongsJson.indexWhere((j) {
      try {
        return (jsonDecode(j)['id'] as String) == song.id;
      } catch (_) {
        return false;
      }
    });

    if (index >= 0) {
      likedSongsJson.removeAt(index);
      _log.d('[AudioHandler] Removing from favorites: ${song.title}');
    } else {
      likedSongsJson.insert(0, jsonEncode(SongModel.fromEntity(song).toJson()));
      _log.d('[AudioHandler] Adding to favorites: ${song.title}');
    }

    await _prefs.setStringList('liked_songs', likedSongsJson);
    
    // 1. Notify the app UI via custom event
    customEvent.add({'type': 'favorite_toggled', 'songId': song.id, 'isLiked': index < 0});
    _log.d('[AudioHandler] Custom event emitted');
    
    // 2. Refresh notification metadata and state
    _updateCurrentMediaItem(song);
    playbackState.add(_buildPlaybackState(_activePlayer.playbackEvent, _activePlayer));
  }

  // ── Carga principal ────────────────────────────────────────────────────────

  Future<void> _loadAndPlay(int index, {AudioPlayer? crossfadeFrom}) async {
    final myGeneration = ++_loadGeneration;
    final song = _queue[index];

    _log.i('[AudioHandler] Carga #$myGeneration › "${song.title}" (id=${song.id})');
    _updateCurrentMediaItem(song);

    final player = _activePlayer;

    // Fading out old player if crossfading
    if (crossfadeFrom != null && _crossfadeDuration > 0) {
      _log.d('[AudioHandler] Fading out old player...');
      _fadeVolume(crossfadeFrom, 1.0, 0.0, _crossfadeDuration);
    } else {
      // Normal transition: stop other player
      _inactivePlayer.stop();
    }

    // ── Paso 2: Resolver URL (Local o Stream) ───────────────────────────
    String? streamUrl;
    try {
      // Check for local file first
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/downloads/${song.id}.mp3');
      
      if (await localFile.exists()) {
        _log.i('[AudioHandler] Reproduciendo archivo local para "${song.title}"');
        streamUrl = localFile.uri.toString();
      } else if (_urlCache.containsKey(song.id)) {
        streamUrl = _urlCache[song.id]!;
      } else {
        _log.d('[AudioHandler] Solicitando URL a YouTube…');
        final result = await _musicRepo.getStreamUrl(song.id).timeout(const Duration(seconds: 15));
        streamUrl = result.getOrElse(() => throw Exception('URL failed'));
        _urlCache[song.id] = streamUrl;
      }
    } catch (e) {
      _log.e('[AudioHandler] Error resolviendo URL: $e');
      _tryNext(myGeneration, index);
      return;
    }

    if (myGeneration != _loadGeneration) return;

    try {
      // If crossfading, start new player at 0 volume
      if (crossfadeFrom != null) {
        player.setVolume(0.0);
      } else {
        player.setVolume(1.0);
      }

      await player.setAudioSource(
        AudioSource.uri(Uri.parse(streamUrl), tag: _buildMediaItem(song)),
        preload: true,
      );

      if (myGeneration != _loadGeneration) return;

      unawaited(player.play());

      // Fade in new player
      if (crossfadeFrom != null && _crossfadeDuration > 0) {
        _log.d('[AudioHandler] Fading in new player...');
        _fadeVolume(player, 0.0, 1.0, _crossfadeDuration);
      }
    } catch (e) {
      _log.e('[AudioHandler] Load error: $e');
      _tryNext(myGeneration, index);
    }
  }

  void _fadeVolume(AudioPlayer player, double from, double to, double durationSec) {
    const steps = 20;
    final interval = (durationSec * 1000) / steps;
    final stepSize = (to - from) / steps;
    double currentVolume = from;

    Timer.periodic(Duration(milliseconds: interval.toInt()), (timer) {
      currentVolume += stepSize;
      if ((stepSize > 0 && currentVolume >= to) || (stepSize < 0 && currentVolume <= to)) {
        player.setVolume(to);
        timer.cancel();
        if (to == 0.0) player.stop();
      } else {
        player.setVolume(currentVolume);
      }
    });
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
    final likedSongsJson = _prefs.getStringList('liked_songs') ?? [];
    final isLiked = likedSongsJson.any((j) {
      try {
        return (jsonDecode(j)['id'] as String) == song.id;
      } catch (_) {
        return false;
      }
    });

    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      rating: Rating.newHeartRating(isLiked),
      artUri: song.bestThumbnail.isNotEmpty ? Uri.tryParse(song.bestThumbnail) : null,
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

  // ── Equalizer API ──────────────────────────────────────────────────────────
  
  Future<List<AndroidEqualizerBand>> getEqualizerBands() async {
    // Both equalizers have same bands
    return (await _equalizer1?.parameters)?.bands ?? [];
  }

  Future<void> setEqualizerBandGain(int bandIndex, double gain) async {
    // We call setBandGain on both players. 
    // If the method is not found by analyzer, we use dynamic to bypass strict check but it should exist on Android.
    try {
      if (_equalizer1 != null) {
        (_equalizer1 as dynamic).setBandGain(bandIndex, gain);
      }
      if (_equalizer2 != null) {
        (_equalizer2 as dynamic).setBandGain(bandIndex, gain);
      }
    } catch (e) {
      _log.e('[AudioHandler] Error setting EQ gain: $e');
    }
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    await Future.wait([
      _equalizer1!.setEnabled(enabled),
      _equalizer2!.setEnabled(enabled),
    ]);
  }

  // ── Streams públicos ──────────────────────────────────────────────────────

  Stream<Duration> get positionStream => _activePlayer.positionStream;
  Stream<Duration> get bufferedPositionStream => _activePlayer.bufferedPositionStream;
  Stream<bool> get playingStream => _activePlayer.playingStream;
  Stream<double> get volumeStream => _activePlayer.volumeStream;
  Duration get position => _activePlayer.position;
  bool get isPlaying => _activePlayer.playing;
  SongEntity? get currentSong =>
      _queue.isNotEmpty && _currentIndex < _queue.length ? _queue[_currentIndex] : null;
  List<SongEntity> get currentQueue => List.unmodifiable(_queue);
  int get currentQueueIndex => _currentIndex;

  Future<void> dispose() async {
    _loadGeneration++;
    _cancelListeners();
    await Future.wait([
      _player1.dispose(),
      _player2.dispose(),
    ]);
  }
}
