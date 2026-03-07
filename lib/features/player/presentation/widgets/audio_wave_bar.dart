import 'dart:math';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AudioWaveBar — Animated reactive audio visualization bars
// ─────────────────────────────────────────────────────────────────────────────

class AudioWaveBar extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final int barCount;

  const AudioWaveBar({
    super.key,
    required this.isPlaying,
    required this.color,
    this.barCount = 32,
  });

  @override
  State<AudioWaveBar> createState() => _AudioWaveBarState();
}

class _AudioWaveBarState extends State<AudioWaveBar>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _controllers = List.generate(widget.barCount, (i) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: 400 + _random.nextInt(600),
        ),
      );
      return controller;
    });

    _animations = _controllers.map((c) {
      return Tween<double>(
        begin: 0.1,
        end: 0.4 + _random.nextDouble() * 0.6,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut));
    }).toList();

    if (widget.isPlaying) _startAnimations();
  }

  void _startAnimations() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 30), () {
        if (mounted && _controllers[i].status != AnimationStatus.forward) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  void _pauseAnimations() {
    for (final c in _controllers) {
      c.stop();
      c.animateTo(0.05, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void didUpdateWidget(AudioWaveBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _startAnimations();
      } else {
        _pauseAnimations();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.barCount, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (_, __) {
              final height = 36 * _animations[i].value;
              return Container(
                width: 3,
                height: height.clamp(3.0, 36.0),
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(
                    0.4 + _animations[i].value * 0.6,
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
