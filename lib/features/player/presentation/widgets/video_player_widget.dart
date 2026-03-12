import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flowy/features/player/presentation/providers/player_provider.dart';
import 'package:provider/provider.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String streamUrl;
  final bool isPlaying;
  final Duration position;

  const VideoPlayerWidget({
    super.key,
    required this.streamUrl,
    required this.isPlaying,
    required this.position,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  String? _loadedUrl;

  Duration? _lastSentPosition;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _initializePlayer();
    } else if (_isInitialized) {
      // Sincronizar play/pause
      if (widget.isPlaying && !_videoController!.value.isPlaying) {
        _videoController!.play();
      } else if (!widget.isPlaying && _videoController!.value.isPlaying) {
        _videoController!.pause();
      }
      
      // Sincronizar posición SOLO si el cambio viene de fuera (just_audio)
      // y no es un rebote de lo que acabamos de enviar desde el video.
      if (oldWidget.position != widget.position) {
        final diff = (widget.position - _videoController!.value.position).inSeconds.abs();
        if (diff > 2) {
          final isRecentBounce = _lastSentPosition != null && 
              (widget.position - _lastSentPosition!).inSeconds.abs() <= 2;
          
          if (!isRecentBounce) {
            _videoController!.seekTo(widget.position);
          }
        }
      }
    }
  }

  void _onVideoControllerUpdate() {
    if (!_isInitialized || _videoController == null) return;

    final videoPos = _videoController!.value.position;
    final diff = (videoPos - widget.position).inSeconds.abs();

    // Si el video se movió manualmente (más de 3 segundos de diferencia con el audio)
    if (diff > 3) {
      // Evitar bucles: solo enviar si es un cambio "nuevo" respecto al último enviado
      final isNewSeek = _lastSentPosition == null || 
          (videoPos - _lastSentPosition!).inSeconds.abs() > 2;

      if (isNewSeek) {
        _lastSentPosition = videoPos;
        // Notificar al PlayerProvider para que mueva el audio
        context.read<PlayerProvider>().seekTo(videoPos);
      }
    }

    // Limpiar el lastSentPosition si ya estamos en sincronía básica (avance normal)
    if (diff <= 1) {
      _lastSentPosition = null;
    }
  }

  Future<void> _initializePlayer() async {
    if (_loadedUrl == widget.streamUrl && _videoController != null) return;

    await _disposeControllers();

    _loadedUrl = widget.streamUrl;
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.streamUrl),
      httpHeaders: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10; SM-G960F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
        'Referer': 'https://music.youtube.com/',
      },
    );

    try {
      await _videoController!.initialize();
      _videoController!.addListener(_onVideoControllerUpdate);
      
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: widget.isPlaying,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        aspectRatio: _videoController!.value.aspectRatio,
        placeholder: Container(color: Colors.black),
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
      );

      // Mutear video para evitar duplicar el audio (just_audio ya lo reproduce)
      await _videoController!.setVolume(0.0);
      await _videoController!.seekTo(widget.position);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Video Player Error: $e');
    }
  }

  Future<void> _disposeControllers() async {
    _isInitialized = false;
    if (_videoController != null) {
      _videoController!.removeListener(_onVideoControllerUpdate);
    }
    if (_chewieController != null) _chewieController!.dispose();
    if (_videoController != null) await _videoController!.dispose();
    _chewieController = null;
    _videoController = null;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _chewieController == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      color: Colors.black,
      child: Chewie(controller: _chewieController!),
    );
  }
}
