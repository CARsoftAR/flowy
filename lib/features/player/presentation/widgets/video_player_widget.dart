import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:chewie/chewie.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String songId;
  final String streamUrl;
  final bool isPlaying;
  final Duration position;

  const VideoPlayerWidget({
    super.key,
    required this.songId,
    required this.streamUrl,
    required this.isPlaying,
    required this.position,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  Player? _mkPlayer;
  VideoController? _mkController;

  vp.VideoPlayerController? _vpController;
  ChewieController? _chewieController;

  bool _isInitialized = false;
  String? _loadedUrl;
  String _debugInfo = 'Starting...';
  int _textureId = -1;
  
  Timer? _pollingTimer;
  List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    debugPrint('[VideoPlayer] initState');
    _initializePlayer();
    
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkTexture();
    });
  }

  void _setupWindowsListeners() {
    if (_mkPlayer == null) return;
    _subscriptions.add(_mkPlayer!.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          final state = _mkPlayer!.state;
          _debugInfo = 'Res: ${state.width}x${state.height} | Tracks: ${state.tracks.video.length} | Play: $playing';
        });
      }
    }));
    _subscriptions.add(_mkPlayer!.stream.width.listen((width) {
      if (mounted) {
        setState(() {
          final state = _mkPlayer!.state;
          _debugInfo = 'Res: ${width}x${state.height} | Tracks: ${state.tracks.video.length} | Play: ${state.playing}';
        });
      }
    }));
  }

  void _checkTexture() {
    if (_mkController != null && mounted) {
      final newTextureId = _mkController!.id.value ?? -1;
      if (newTextureId != _textureId && newTextureId > 0) {
        debugPrint('[VideoPlayer] Texture poll: $_textureId -> $newTextureId');
        setState(() {
          _textureId = newTextureId;
        });
      }
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _initializePlayer();
    } else if (_isInitialized) {
      _syncPlayback();
    }
  }

  void _syncPlayback() {
    if (Platform.isWindows) {
      if (_mkPlayer == null) return;
      if (widget.isPlaying && !_mkPlayer!.state.playing) {
        _mkPlayer!.play();
      } else if (!widget.isPlaying && _mkPlayer!.state.playing) {
        _mkPlayer!.pause();
      }
      final diff = (widget.position - _mkPlayer!.state.position).inSeconds.abs();
      if (diff > 2) _mkPlayer!.seek(widget.position);
    } else {
      if (_vpController == null || !_vpController!.value.isInitialized) return;
      if (widget.isPlaying && !_vpController!.value.isPlaying) {
        _vpController!.play();
      } else if (!widget.isPlaying && _vpController!.value.isPlaying) {
        _vpController!.pause();
      }
      final diff = (widget.position - _vpController!.value.position).inSeconds.abs();
      if (diff > 2) _vpController!.seekTo(widget.position);
    }
  }

  Future<void> _initializePlayer() async {
    if (_loadedUrl == widget.streamUrl && _isInitialized) return;
    _loadedUrl = widget.streamUrl;

    await _disposeControllers();

    if (Platform.isWindows) {
      await _initWindowsNative();
    } else {
      await _initMobilePlayer();
    }
  }

  Future<void> _initWindowsNative() async {
    try {
      _debugInfo = '1. Creating Player...';
      if (mounted) setState(() {});
      
      _mkPlayer = Player();
      _setupWindowsListeners();

      // Configuración de RED y CACHÉ (Evitar I/O Errors y Hangs en Windows)
      final player = _mkPlayer;
      if (player is dynamic) {
        try {
          await (player as dynamic).setProperty('ytdl', 'no');
          await (player as dynamic).setProperty('cache', 'no'); 
          await (player as dynamic).setProperty('demuxer-max-bytes', '67108864'); 
          await (player as dynamic).setProperty('tls-verify', 'no');
          await (player as dynamic).setProperty('network-timeout', '15');
          await (player as dynamic).setProperty('hwdec', 'auto-safe'); 
          await (player as dynamic).setProperty('vo', 'gpu');
          await (player as dynamic).setProperty('user-agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');
        } catch (e) {
          debugPrint('[VideoPlayer] MPV Property Error: $e');
        }
      }
      
      _debugInfo = '2. Creating VideoController...';
      if (mounted) setState(() {});
      
      _mkController = VideoController(
        _mkPlayer!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );
      
      _textureId = _mkController!.id.value ?? -1;
      _debugInfo = '3. Setting volume...';
      if (mounted) setState(() {});
      await _mkPlayer!.setVolume(0);

      if (widget.streamUrl.isNotEmpty) {
        final shortUrl = widget.streamUrl.length > 30 ? widget.streamUrl.substring(0, 30) : widget.streamUrl;
        _debugInfo = '4. Opening: $shortUrl...';
        if (mounted) setState(() {});
        
        final media = Media(
          widget.streamUrl,
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Referer': 'https://www.youtube.com',
          },
        );
        
        await _mkPlayer!.open(media, play: widget.isPlaying);
        await _mkPlayer!.setVideoTrack(VideoTrack.auto());
        await _mkPlayer!.seek(widget.position);
      }

      // Dejar que el motor respire y cargue el primer frame
      await Future.delayed(const Duration(seconds: 3));

      final state = _mkPlayer!.state;
      final playing = state.playing;
      final tracks = state.tracks.video.length;
      final width = state.width;
      final height = state.height;
      
      _debugInfo = 'Res: ${width}x${height} | Tracks: $tracks | Play: $playing';
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e, st) {
      _debugInfo = 'ERROR: $e';
      debugPrint('[VideoPlayer] ERROR: $e');
      debugPrint('[VideoPlayer] Stack: $st');
    }
  }

  Future<void> _initMobilePlayer() async {
    _vpController = vp.VideoPlayerController.networkUrl(Uri.parse(widget.streamUrl));
    try {
      await _vpController!.initialize();
      await _vpController!.setVolume(0);
      _chewieController = ChewieController(
        videoPlayerController: _vpController!,
        autoPlay: widget.isPlaying,
        showControls: false,
        aspectRatio: _vpController!.value.aspectRatio,
      );
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Mobile Video Player Error: $e');
    }
  }

  Future<void> _disposeControllers() async {
    _isInitialized = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;

    for (var s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    
    final mk = _mkPlayer;
    final vp = _vpController;
    final ch = _chewieController;

    _mkPlayer = null;
    _mkController = null;
    _vpController = null;
    _chewieController = null;

    if (ch != null) ch.dispose();
    if (vp != null) await vp.dispose();
    if (mk != null) await mk.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[VideoPlayer] BUILD: isInit=$_isInitialized, texture=$_textureId');
    
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white24, strokeWidth: 2),
              const SizedBox(height: 16),
              Text(
                _debugInfo,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (Platform.isWindows && _mkController != null) {
      return Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isInitialized)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Video(
                  controller: _mkController!,
                  fill: Colors.black,
                  fit: BoxFit.contain,
                ),
              )
            else
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white24, strokeWidth: 2),
                    SizedBox(height: 16),
                    Text(
                      'Cargando video...',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black54,
                child: Text(
                  _debugInfo,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_chewieController != null) {
      return Container(
        color: Colors.black,
        child: Chewie(controller: _chewieController!),
      );
    }

    return const SizedBox.shrink();
  }
}

class RawTexture extends StatelessWidget {
  final int textureId;
  
  const RawTexture({super.key, required this.textureId});

  @override
  Widget build(BuildContext context) {
    return Texture(textureId: textureId);
  }
}
