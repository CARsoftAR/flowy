import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:chewie/chewie.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String songId;
  final String streamUrl;
  final String coverUrl;
  final bool isPlaying;
  final Duration position;

  const VideoPlayerWidget({
    super.key,
    required this.songId,
    required this.streamUrl,
    required this.coverUrl,
    required this.isPlaying,
    required this.position,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  // ── media_kit (Windows) ───────────────────────────────────────────────────
  Player? _mkPlayer;
  VideoController? _mkController;

  // ── video_player + chewie (Mobile) ────────────────────────────────────────
  vp.VideoPlayerController? _vpController;
  ChewieController? _chewieController;

  // ── State ─────────────────────────────────────────────────────────────────
  bool _videoReady = false;   // video decoded & can paint frames
  bool _hasError = false;     // network / decode failure
  String? _loadedUrl;

  Timer? _pollingTimer;
  final List<StreamSubscription> _subscriptions = [];

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initializePlayer();
    // Poll texture availability on Windows
    if (Platform.isWindows) {
      _pollingTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        _checkWindowsTexture();
      });
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _initializePlayer();
    } else if (_videoReady) {
      _syncPlayback();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  // ── Playback sync ─────────────────────────────────────────────────────────

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

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> _initializePlayer() async {
    if (_loadedUrl == widget.streamUrl && _videoReady) return;
    _loadedUrl = widget.streamUrl;

    await _disposeControllers();
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (Platform.isWindows) {
      await _initWindowsNative();
    } else {
      await _initMobilePlayer();
    }
  }

  // ── Windows (media_kit) ───────────────────────────────────────────────────

  Future<void> _initWindowsNative() async {
    try {
      _mkPlayer = Player();
      _setupWindowsListeners();

      // MPV options (video-only overlay, no audio re-output)
      final player = _mkPlayer as dynamic;
      try {
        await player.setProperty('ao', 'null');
        await player.setProperty('cache', 'no');
        await player.setProperty('tls-verify', 'no');
        await player.setProperty('network-timeout', '15');
        await player.setProperty('hwdec', 'auto-safe');
        await player.setProperty(
          'user-agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        );
      } catch (_) {}

      _mkController = VideoController(
        _mkPlayer!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );

      await _mkPlayer!.setVolume(0);

      if (widget.streamUrl.isNotEmpty) {
        final media = Media(
          widget.streamUrl,
          httpHeaders: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Referer': 'https://www.youtube.com',
          },
        );
        await _mkPlayer!.open(media, play: widget.isPlaying);
        await _mkPlayer!.setVideoTrack(VideoTrack.auto());
        await _mkPlayer!.seek(widget.position);
      }
    } catch (e) {
      debugPrint('[VideoPlayer] Windows init error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _setupWindowsListeners() {
    if (_mkPlayer == null) return;

    // Mark ready once we get a valid resolution
    _subscriptions.add(_mkPlayer!.stream.width.listen((width) {
      if (width != null && width > 0 && mounted && !_videoReady) {
        setState(() {
          _videoReady = true;
          _hasError = false;
        });
      }
    }));

    _subscriptions.add(_mkPlayer!.stream.error.listen((err) {
      if (err.isNotEmpty && mounted) {
        debugPrint('[VideoPlayer] Stream error: $err');
        setState(() => _hasError = true);
      }
    }));
  }

  void _checkWindowsTexture() {
    if (_mkController == null || !mounted) return;
    final texId = _mkController!.id.value ?? -1;
    if (texId > 0 && !_videoReady) {
      setState(() {
        _videoReady = true;
        _hasError = false;
      });
    }
  }

  // ── Mobile (video_player + chewie) ────────────────────────────────────────

  Future<void> _initMobilePlayer() async {
    try {
      _vpController = vp.VideoPlayerController.networkUrl(
        Uri.parse(widget.streamUrl),
        videoPlayerOptions: vp.VideoPlayerOptions(mixWithOthers: true),
        httpHeaders: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
          'Referer': 'https://www.youtube.com',
        },
      );

      await _vpController!.initialize();
      await _vpController!.setVolume(0);

      _chewieController = ChewieController(
        videoPlayerController: _vpController!,
        autoPlay: widget.isPlaying,
        showControls: false,
        aspectRatio: _vpController!.value.aspectRatio,
      );

      if (mounted) {
        setState(() {
          _videoReady = true;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('[VideoPlayer] Mobile init error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> _disposeControllers() async {
    _videoReady = false;
    _hasError = false;

    _pollingTimer?.cancel();
    _pollingTimer = null;

    for (final s in _subscriptions) s.cancel();
    _subscriptions.clear();

    final mk = _mkPlayer;
    final vpCtrl = _vpController;
    final ch = _chewieController;

    _mkPlayer = null;
    _mkController = null;
    _vpController = null;
    _chewieController = null;

    ch?.dispose();
    if (vpCtrl != null) await vpCtrl.dispose();
    if (mk != null) await mk.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Layer 1: Cover art (always present as background) ────────────────
        CachedNetworkImage(
          imageUrl: widget.coverUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: Colors.black),
          errorWidget: (_, __, ___) => Container(color: Colors.black),
        ),

        // ── Layer 2: Video (fades in on top when ready, hidden on error) ─────
        if (!_hasError)
          AnimatedOpacity(
            opacity: _videoReady ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeIn,
            child: _buildVideoLayer(),
          ),

        // ── Layer 3: Centered loading indicator (only while loading) ─────────
        if (!_videoReady && !_hasError)
          const Center(
            child: CircularProgressIndicator(
              color: Colors.white54,
              strokeWidth: 2,
            ),
          ),
      ],
    );
  }

  Widget _buildVideoLayer() {
    if (Platform.isWindows && _mkController != null) {
      return Video(
        controller: _mkController!,
        fill: Colors.transparent,
        fit: BoxFit.cover,
      );
    }
    if (_chewieController != null) {
      return Chewie(controller: _chewieController!);
    }
    return const SizedBox.shrink();
  }
}
