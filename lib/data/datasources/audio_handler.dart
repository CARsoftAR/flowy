import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/song_model.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import 'package:rxdart/rxdart.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FlowyAudioHandler — v5 (Architected for Stability & Long-form content)
// ─────────────────────────────────────────────────────────────────────────────

typedef OnPlayerError = void Function(String message);

class FlowyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final MusicRepository _musicRepo;
  final Logger _log;

  OnPlayerError? onError;

  List<SongEntity> _queue = [];
  int _currentIndex = 0;
  int _loadGeneration = 0;
  int _consecutiveFailures = 0;

  late final AudioPlayer _player1;
  late final AudioPlayer _player2;
  bool _usePlayer1 = true;
  
  AudioPlayer get _activePlayer => _usePlayer1 ? _player1 : _player2;
  AudioPlayer get _inactivePlayer => _usePlayer1 ? _player2 : _player1;

  AndroidEqualizer? _equalizer1;
  AndroidEqualizer? _equalizer2;

  final List<StreamSubscription> _subs = [];
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
    _player1 = AudioPlayer();
    _player2 = AudioPlayer();
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
    _listenToPlayer(_player1);
    _listenToPlayer(_player2);
  }

  void _listenToPlayer(AudioPlayer player) {
    _subs.add(player.playbackEventStream.listen(
      (event) {
        if (player == _activePlayer) {
          try {
            playbackState.add(_buildPlaybackState(event, player));
          } catch (e) {
            _log.w('[AudioHandler] playbackState.add error: $e');
          }
        }
      },
      onError: (Object e, StackTrace st) {
        _log.e('[AudioHandler] PlaybackEventStream Error', error: e, stackTrace: st);
        if (player == _activePlayer) {
          onError?.call('Error de fuente de audio: $e');
        }
      },
    ));

    _subs.add(player.processingStateStream.listen(
      (state) {
        if (player == _activePlayer && state == ProcessingState.completed) {
          _log.d('[AudioHandler] Playback completed. Advancing.');
          unawaited(_advanceToNext());
        }
      },
      onError: (Object e, StackTrace st) {
        _log.e('[AudioHandler] ProcessingStateStream Error', error: e, stackTrace: st);
      },
    ));

    _subs.add(player.positionStream.listen((pos) {
      final songId = currentSong?.id;
      // Precision saving for long tracks: Every 5 seconds
      if (songId != null && pos.inSeconds > 5 && pos.inSeconds % 5 == 0) {
        try {
          _prefs.setInt('bookmark_$songId', pos.inSeconds);
        } catch (_) {
          // Ignorar errores de persistencia en tiempo real para no tumbar la app
        }
      }
      
      if (player == _activePlayer && _crossfadeDuration > 0) {
        final remaining = (player.duration ?? Duration.zero) - pos;
        if (remaining.inMilliseconds > 0 && 
            remaining.inMilliseconds <= (_crossfadeDuration * 1000) &&
            _currentIndex < _queue.length - 1 &&
            player.playing) {
          _checkAndTriggerCrossfade(player);
        }
      }
    }));
  }

  bool _isCrossfading = false;
  void _checkAndTriggerCrossfade(AudioPlayer sourcePlayer) {
    if (_isCrossfading) return;
    _isCrossfading = true;
    unawaited(_crossfadeToNext());
  }

  Future<void> _crossfadeToNext() async {
    final oldPlayer = _activePlayer;
    final nextIdx = _currentIndex + 1;
    _usePlayer1 = !_usePlayer1;
    _currentIndex = nextIdx;
    await _loadAndPlay(_currentIndex, crossfadeFrom: oldPlayer);
    _isCrossfading = false;
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);

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
    if (_queue.isEmpty) return;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      await _loadAndPlay(_currentIndex);
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
        isLiked ? _favoriteOn : _favoriteOff,
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
      }[player.processingState] ?? AudioProcessingState.idle,
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: _currentIndex,
    );
  }

  // ── API ────────────────────────────────────────────────────────────────────

  Future<void> playSong(SongEntity song, {List<SongEntity>? playQueue}) async {
    _queue = playQueue ?? [song];
    final idx = _queue.indexWhere((s) => s.id == song.id);
    _currentIndex = idx < 0 ? 0 : idx;
    _updateQueueMetadata();
    await _loadAndPlay(_currentIndex);
  }

  @override
  Future<void> play() async => _activePlayer.play();

  @override
  Future<void> pause() async => _activePlayer.pause();

  @override
  Future<void> stop() async {
    _loadGeneration++;
    _queue = [];
    try {
      await Future.wait([_player1.stop(), _player2.stop()]);
    } catch (_) {}
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async => _activePlayer.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      await _loadAndPlay(_currentIndex);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_activePlayer.position.inSeconds > 3) {
      await seek(Duration.zero);
    } else if (_currentIndex > 0) {
      _currentIndex--;
      await _loadAndPlay(_currentIndex);
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

  Future<void> setSpeed(double speed) async {
    await Future.wait([
      _player1.setSpeed(speed),
      _player2.setSpeed(speed),
    ]);
  }

  @override
  Future<void> setRating(Rating rating, [Map<String, dynamic>? extras]) async {
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
    } else {
      likedSongsJson.insert(0, jsonEncode(SongModel.fromEntity(song).toJson()));
    }

    await _prefs.setStringList('liked_songs', likedSongsJson);
    customEvent.add({'type': 'favorite_toggled', 'songId': song.id, 'isLiked': index < 0});
    _updateCurrentMediaItem(song);
    playbackState.add(_buildPlaybackState(_activePlayer.playbackEvent, _activePlayer));
  }

  // ── Core Loading ──────────────────────────────────────────────────────────

  Future<void> _loadAndPlay(int index, {AudioPlayer? crossfadeFrom}) async {
    final myGeneration = ++_loadGeneration;
    final song = _queue[index];

    _log.i('[AudioEngine] Loading gen #$myGeneration › "${song.title}"');
    
    // Mandatory reset/stop for the player we are about to use
    final player = _activePlayer;
    await player.stop(); // Ensura it's clean

    _updateCurrentMediaItem(song);

    if (crossfadeFrom != null) {
      _fadeVolume(crossfadeFrom, 1.0, 0.0, _crossfadeDuration);
    } else {
      _inactivePlayer.stop();
    }

    // Resolve URL
    String? streamUrl;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/downloads/${song.id}.mp3');
      
      bool isLocal = false;
      if (await localFile.exists()) {
        streamUrl = localFile.uri.toString();
        isLocal = true;
      } else {
        final result = await _musicRepo.getStreamUrl(song.id, isVideo: song.isVideo).timeout(const Duration(seconds: 15));
        streamUrl = result.getOrElse(() => throw Exception('URL failed'));
      }
    } catch (e) {
      _log.e('[AudioEngine] URL Resolution Error: $e');
      _consecutiveFailures++;
      
      final isLast = index >= _queue.length - 1;
      if (isLast || _consecutiveFailures >= 3) {
        final reason = _consecutiveFailures >= 3 
            ? 'No se pudieron obtener URLs de stream. YouTube puede estar bloqueando la petición.' 
            : 'No se pudo obtener la URL de reproducción.';
        onError?.call(reason);
        _consecutiveFailures = 0;
      } else {
        _log.w('[AudioEngine] Skipping to next due to URL failure ($_consecutiveFailures consecutive)');
        _tryNext(myGeneration, index);
      }
      return;
    }

    if (myGeneration != _loadGeneration) return;

    try {
      player.setVolume(crossfadeFrom != null ? 0.0 : 1.0);

      // Solo aplicar headers si es una URL de red (HTTP/HTTPS)
      // Esto evita errores de PlatformException al intentar leer archivos locales con headers web
      final isNetwork = streamUrl.startsWith('http');
      
      await player.setAudioSource(
        AudioSource.uri(
          Uri.parse(streamUrl), 
          tag: _buildMediaItem(song),
          headers: isNetwork ? {
            // Un User-Agent de dispositivo móvil genérico pero moderno es lo más seguro
            'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
          } : null,
        ),
        preload: true,
      ).timeout(const Duration(seconds: 25)); // Aumentado para podcasts pesados

      if (myGeneration != _loadGeneration) return;

      // Handle Bookmark Resume Prompt
      final savedSeconds = _prefs.getInt('bookmark_${song.id}');
      if (savedSeconds != null && savedSeconds > 10) {
        customEvent.add({
          'type': 'request_resume',
          'songId': song.id,
          'seconds': savedSeconds,
          'title': song.title
        });
      }

      await player.play();
      _consecutiveFailures = 0; // Reset on success

      if (crossfadeFrom != null) {
        _fadeVolume(player, 0.0, 1.0, _crossfadeDuration);
      }
    } catch (e) {
      _log.e('[AudioEngine] Player Error: $e');
      _consecutiveFailures++;
      
      final isLast = index >= _queue.length - 1;
      if (isLast || _consecutiveFailures >= 3) {
        final reason = _consecutiveFailures >= 3 
            ? 'Múltiples temas fallaron al cargar. Verifica tu conexión.' 
            : 'Error de reproducción: $e';
        onError?.call(reason);
        _consecutiveFailures = 0; // Reset after reporting
      } else {
        // Report skip to UI silently or via logs
        _log.w('[AudioEngine] Skipping to next due to failure ($_consecutiveFailures consecutive)');
        _tryNext(myGeneration, index);
      }
    }
  }

  void _fadeVolume(AudioPlayer player, double from, double to, double durationSec) {
    if (durationSec <= 0) {
      player.setVolume(to);
      return;
    }
    const steps = 10;
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

  void _tryNext(int generation, int failedIndex) {
    if (generation != _loadGeneration) return;
    if (failedIndex < _queue.length - 1) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (generation == _loadGeneration) {
          _currentIndex = failedIndex + 1;
          unawaited(_loadAndPlay(_currentIndex));
        }
      });
    }
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
      extras: {
        'source': 'youtube',
        'isVideo': song.isVideo,
      },
    );
  }

  void _updateQueueMetadata() {
    queue.add(_queue.map(_buildMediaItem).toList());
  }

  // ── Equalizer ──────────────────────────────────────────────────────────────
  
  Future<List<AndroidEqualizerBand>> getEqualizerBands() async {
    return (await _equalizer1?.parameters)?.bands ?? [];
  }

  Future<void> setEqualizerBandGain(int bandIndex, double gain) async {
    try {
      if (_equalizer1 != null) (_equalizer1 as dynamic).setBandGain(bandIndex, gain);
      if (_equalizer2 != null) (_equalizer2 as dynamic).setBandGain(bandIndex, gain);
    } catch (_) {}
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    if (_equalizer1 != null) await _equalizer1!.setEnabled(enabled);
    if (_equalizer2 != null) await _equalizer2!.setEnabled(enabled);
  }

  Stream<Duration> get positionStream => _activePlayer.positionStream;
  Stream<Duration> get bufferedPositionStream => _activePlayer.bufferedPositionStream;
  Stream<bool> get playingStream => _activePlayer.playingStream;
  Duration get position => _activePlayer.position;
  SongEntity? get currentSong => _queue.isNotEmpty && _currentIndex < _queue.length ? _queue[_currentIndex] : null;
  List<SongEntity> get currentQueue => List.unmodifiable(_queue);
  int get currentQueueIndex => _currentIndex;
  String? getCachedUrl(String songId) => _urlCache[songId];

  Future<void> dispose() async {
    _loadGeneration++;
    for (final sub in _subs) { sub.cancel(); }
    await Future.wait([_player1.dispose(), _player2.dispose()]);
  }
}
