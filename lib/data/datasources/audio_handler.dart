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
// FlowyAudioHandler — v10 (Ultimate Windows Stabilization)
// ─────────────────────────────────────────────────────────────────────────────

typedef OnPlayerError = void Function(String message);

class FlowyAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final MusicRepository _musicRepo;
  final Logger _log;
  final SharedPreferences _prefs;

  OnPlayerError? onError;

  List<SongEntity> _queue = [];
  int _currentIndex = 0;
  int _loadGeneration = 0;

  late AudioPlayer _player;
  late AudioPlayer _nextPlayer;
  final List<StreamSubscription> _subs = [];
  final Map<String, String?> _urlCache = {};
  final Map<String, String?> _videoUrlCache = {};

  File? _debugLog;

  double _crossfadeDuration = 0.0;
  double _currentVolume = 1.0;
  Timer? _crossfadeTimer;
  bool _isCrossfading = false;

  FlowyAudioHandler({
    required MusicRepository musicRepository,
    required SharedPreferences sharedPreferences,
    Logger? logger,
    this.onError,
  })  : _musicRepo = musicRepository,
        _prefs = sharedPreferences,
        _log = logger ?? Logger(printer: PrettyPrinter(methodCount: 0)) {
    _player = AudioPlayer();
    _nextPlayer = AudioPlayer();
    _initDebug();
    _attachListeners();
  }

  Future<void> _initDebug() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _debugLog = File('${dir.path}/player_debug.log');
      await _writeDebug('--- HANDLER V10 START ---');
    } catch (_) {}
  }

  Future<void> _writeDebug(String msg) async {
    final now = DateTime.now().toLocal().toString().split(' ')[1];
    final line = '[$now] $msg\n';
    print('[DEBUG] $line');
    try {
      await _debugLog?.writeAsString(line, mode: FileMode.append);
    } catch (_) {}
  }

  void _attachListeners() {
    _subs.add(_player.playbackEventStream.listen(
      (event) {
        _updateState();
      },
      onError: (Object e) => _writeDebug('Playback Stream Error: $e'),
    ));

    _subs.add(_player.processingStateStream.listen((state) {
      _writeDebug('Native State: $state');
      if (state == ProcessingState.completed) {
        if (_player.loopMode == LoopMode.one) {
          _player.seek(Duration.zero);
          _player.play();
          _updateState();
        } else {
          skipToNext();
        }
      }
      _updateState();
    }));

    _subs.add(_player.positionStream.listen((pos) {
      if (pos.inSeconds % 5 == 0) _updateState();
      if (pos == Duration.zero && _player.playing) {
        _updateState();
      }
      if (_player.loopMode == LoopMode.one && pos.inSeconds > 0) {
        final duration = _player.duration?.inSeconds ?? 0;
        if (duration > 0 && pos.inSeconds >= duration - 1) {
          _player.seek(Duration.zero);
        }
      }

      // Crossfade logic
      if (_crossfadeDuration > 0 && !_isCrossfading && _queue.length > 1) {
        final duration = _player.duration?.inSeconds ?? 0;
        if (duration > 0 && pos.inSeconds >= duration - _crossfadeDuration) {
          _startCrossfade();
        }
      }
    }));

    _subs.add(_player.positionStream.listen((pos) {
      // Periodic update to ensure UI is synced
      if (pos.inSeconds % 5 == 0) _updateState();
    }));
  }

  void _updateState() {
    try {
      playbackState.add(PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
              ProcessingState.idle: AudioProcessingState.idle,
              ProcessingState.loading: AudioProcessingState.loading,
              ProcessingState.buffering: AudioProcessingState.buffering,
              ProcessingState.ready: AudioProcessingState.ready,
              ProcessingState.completed: AudioProcessingState.completed,
            }[_player.processingState] ??
            AudioProcessingState.idle,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
      ));
    } catch (e) {
      _writeDebug('State Update Fail: $e');
    }
  }

  @override
  Future<void> play() async {
    _writeDebug('UI Command: PLAY');
    await _player.setVolume(1.0);
    _player.play(); // Don't await forever if it hangs
    _updateState();
  }

  @override
  Future<void> pause() async {
    _writeDebug('UI Command: PAUSE');
    await _player.pause();
    _updateState();
  }

  @override
  Future<void> stop() async {
    _writeDebug('UI Command: STOP');
    _loadGeneration++;
    await _player.stop();
    _updateState();
    await super.stop();
  }

  @override
  Future<void> playSong(SongEntity song, {List<SongEntity>? playQueue}) async {
    _writeDebug('Starting Song: ${song.title}');
    _queue = playQueue ?? [song];
    final idx = _queue.indexWhere((s) => s.id == song.id);
    _currentIndex = idx < 0 ? 0 : idx;
    _updateQueueMetadata();

    _preloadVideoUrl(song.id);

    await _loadAndPlay(_currentIndex);
  }

  Future<void> _preloadVideoUrl(String videoId) async {
    _writeDebug('🎥 Video preload start: $videoId');
    if (_videoUrlCache.containsKey(videoId)) {
      _writeDebug('🎥 Already cached: $videoId');
      return;
    }
    try {
      _writeDebug('🎥 Calling getStreamUrl(videoId=$videoId, isVideo=true)');
      final result = await _musicRepo
          .getStreamUrl(videoId, isVideo: true)
          .timeout(const Duration(seconds: 25));
      String? url;
      result.fold((err) {
        _writeDebug('🎥 Error getting video: $err');
        url = null;
      }, (u) {
        _writeDebug('🎥 Got video url: ${u?.substring(0, 50)}...');
        url = u;
      });
      if (url != null && url!.isNotEmpty) {
        _videoUrlCache[videoId] = url;
        customEvent
            .add({'type': 'video_url_resolved', 'songId': videoId, 'url': url});
        _writeDebug('🎥 Video URL cached: ${videoId}');
      } else {
        _writeDebug('🎥 No video URL returned');
      }
    } catch (e) {
      _writeDebug('🎥 Video preload failed: $e');
    }
  }

  Future<void> _loadAndPlay(int index) async {
    final myGeneration = ++_loadGeneration;
    final song = _queue[index];

    _writeDebug('Preparing Track: ${song.title} | ID: ${song.id}');

    // Immediate UI update to show we are loading
    mediaItem.add(MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      duration: song.duration,
      artUri: song.bestThumbnail.isNotEmpty
          ? Uri.tryParse(song.bestThumbnail)
          : null,
    ));
    _updateState();

    await _player.stop();

    String? streamUrl;
    try {
    int retries = 0;
    while (retries < 3) {
      try {
        if (song.isDirectStream &&
            song.streamUrl != null &&
            song.streamUrl!.startsWith('http')) {
          streamUrl = song.streamUrl;
          _writeDebug('Using direct stream URL');
        } else if (song.streamUrl != null && song.streamUrl!.startsWith('http')) {
          streamUrl = song.streamUrl;
        } else {
          final result = await _musicRepo
              .getStreamUrl(song.id, isVideo: song.isVideo)
              .timeout(const Duration(seconds: 25));
          streamUrl = result.getOrElse(
              () => throw Exception('No se pudo obtener URL del stream'));
        }
        _urlCache[song.id] = streamUrl;
        customEvent.add({'type': 'url_resolved', 'songId': song.id});
        _writeDebug('Stream Resolved Sucessfully');
        break; // Exit loop if successful
      } catch (e) {
        retries++;
        _writeDebug('❌ Attempt $retries failed: $e');
        if (retries >= 3) {
          final errorMsg = 'Reconectando con el servidor...';
          onError?.call(errorMsg);
          return;
        }
        await Future.delayed(Duration(seconds: 2 * retries));
      }
    }

    // Check if it's an HLS stream (m3u8)
    final isHls = streamUrl?.toLowerCase().contains('.m3u8') ?? false;

    if (myGeneration != _loadGeneration) return;

    try {
      _writeDebug('Loading into Native Player...');

      _writeDebug('FINAL STREAM URL READY: $streamUrl');
      print('URL FINAL DE AUDIO: $streamUrl');

      final source = AudioSource.uri(
        Uri.parse(streamUrl!),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Accept-Language': 'es-ES,es;q=0.9',
          'Connection': 'keep-alive',
        },
      );

      if (isHls) {
        _writeDebug('HLS Live Stream - Fire & Forget Activation');

        // No esperamos al setAudioSource porque en Windows/MediaKit puede
        // bloquearse analizando el manifest de YouTube.
        _player.setAudioSource(source, preload: false);

        if (myGeneration != _loadGeneration) return;

        // Disparamos el play casi de inmediato.
        // El motor nativo se encargará del buffering internamente.
        Future.delayed(const Duration(milliseconds: 300), () {
          if (myGeneration == _loadGeneration) {
            _player.play();
            _updateState();
            _writeDebug('HLS Play command sent (Background)');
          }
        });
      } else {
        _writeDebug('Standard File/Stream - Awaiting load');
        await _player
            .setAudioSource(
              source,
              preload: true, // Cambiado a true para que falle rápido si hay 403
            )
            .timeout(const Duration(
                seconds: 10)); // Timeout más agresivo para forzar error

        if (myGeneration != _loadGeneration) return;

        _writeDebug('Activating Audio...');
        await _player.setVolume(1.0);

        // El play() también puede fallar si el stream se corta
        _player.play().catchError((e) {
          _writeDebug('Play execution fail: $e');
          onError?.call('No se pudo iniciar el audio: $e');
          return null;
        });
      }

      _updateState();
      _writeDebug('Load sequence finished.');
    } catch (e) {
      _writeDebug('Native Player Fail: $e');
      if (!isHls) {
        onError?.call('Reconectando con el servidor...');
      }
    }
  }

  @override
  Future<void> seek(Duration position) async => _player.seek(position);
  @override
  Future<void> skipToNext() async {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _loadAndPlay(_currentIndex);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 5) {
      seek(Duration.zero);
    } else if (_currentIndex > 0) {
      _currentIndex--;
      _loadAndPlay(_currentIndex);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _queue.length) {
      _currentIndex = index;
      _loadAndPlay(_currentIndex);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode rm) async {
    final loop = switch (rm) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all => LoopMode.all,
      _ => LoopMode.off
    };
    await _player.setLoopMode(loop);
  }

  Future<void> setSpeed(double speed) async => _player.setSpeed(speed);
  Future<void> setVolume(double volume) async => _player.setVolume(volume);

  @override
  Future<void> setRating(Rating rating, [Map<String, dynamic>? extras]) async {
    final song = currentSong;
    if (song == null) return;

    // Trigger the same logic as UI toggle
    customEvent.add({'type': 'favorite_toggled', 'songId': song.id});
  }

  void reorderQueue(int old, int next) {
    if (next > old) next -= 1;
    final item = _queue.removeAt(old);
    _queue.insert(next, item);
    _updateQueueMetadata();
  }

  void setQueue(List<SongEntity> queue, int startIndex) {
    _queue = List.from(queue);
    _currentIndex = startIndex;
    _updateQueueMetadata();
    if (_queue.isNotEmpty &&
        _currentIndex >= 0 &&
        _currentIndex < _queue.length) {
      final song = _queue[_currentIndex];
      mediaItem.add(MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        duration: song.duration,
        artUri: Uri.tryParse(song.thumbnailUrl ?? ''),
      ));
    }
  }

  void _updateQueueMetadata() {
    queue.add(_queue
        .map((s) => MediaItem(
            id: s.id, title: s.title, artist: s.artist, duration: s.duration))
        .toList());
  }

  void setCrossfade(double duration) {
    _crossfadeDuration = duration;
  }

  Future<void> _startCrossfade() async {
    if (_isCrossfading || _currentIndex >= _queue.length - 1) return;

    _isCrossfading = true;
    _writeDebug('Starting crossfade to next song');

    final nextIndex = _currentIndex + 1;
    final nextSong = _queue[nextIndex];

    try {
      await _nextPlayer.setUrl(nextSong.streamUrl ?? '');
      await _nextPlayer.setVolume(0.0);
      await _nextPlayer.play();

      // Fade out current, fade in next
      final steps = 20;
      final stepDuration = (_crossfadeDuration * 1000 / steps).round();

      for (int i = 0; i <= steps; i++) {
        final progress = i / steps;
        final volume1 = _currentVolume * (1 - progress);
        final volume2 = _currentVolume * progress;

        await _player.setVolume(volume1);
        await _nextPlayer.setVolume(volume2);

        await Future.delayed(Duration(milliseconds: stepDuration));
      }

      // Swap players
      final tempPlayer = _player;
      _player = _nextPlayer;
      _nextPlayer = tempPlayer;

      _currentIndex = nextIndex;
      _updateQueueMetadata();
      _updateState();

      // Prepare next song for next crossfade
      await _prepareNextForCrossfade();
    } catch (e) {
      _writeDebug('Crossfade error: $e');
      _isCrossfading = false;
    }
  }

  Future<void> _prepareNextForCrossfade() async {
    if (_currentIndex >= _queue.length - 1) return;

    final nextIndex = _currentIndex + 1;
    final nextSong = _queue[nextIndex];

    try {
      await _nextPlayer.setUrl(nextSong.streamUrl ?? '');
      _isCrossfading = false;
    } catch (e) {
      _writeDebug('Prepare next error: $e');
      _isCrossfading = false;
    }
  }

  Future<List<dynamic>> getEqualizerBands() async => [];
  Future<void> setEqualizerBandGain(int i, double g) async {}
  Future<void> setEqualizerEnabled(bool e) async {}
  String? getCachedUrl(String id) {
    return _urlCache[id];
  }

  String? getCachedVideoUrl(String id) {
    return _videoUrlCache[id];
  }

  Future<String?> getVideoUrl(String videoId) async {
    if (_videoUrlCache.containsKey(videoId)) {
      return _videoUrlCache[videoId];
    }
    try {
      final result = await _musicRepo
          .getStreamUrl(videoId, isVideo: true)
          .timeout(const Duration(seconds: 25));
      final url = result.getOrElse(() => '');
      if (url.isNotEmpty) {
        _videoUrlCache[videoId] = url;
      }
      return url;
    } catch (e) {
      return null;
    }
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Duration get position => _player.position;
  SongEntity? get currentSong =>
      _queue.isNotEmpty && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;
  List<SongEntity> get currentQueue => List.unmodifiable(_queue);
  int get currentQueueIndex => _currentIndex;
  Future<void> dispose() async {
    _loadGeneration++;
    _crossfadeTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    await _player.dispose();
    await _nextPlayer.dispose();
  }
}
