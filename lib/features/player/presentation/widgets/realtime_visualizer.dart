
import 'dart:math' as math;
import 'package:flutter/material.dart';

class RealtimeVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;

  const RealtimeVisualizer({
    super.key,
    required this.isPlaying,
    required this.color,
  });

  @override
  State<RealtimeVisualizer> createState() => _RealtimeVisualizerState();
}

class _RealtimeVisualizerState extends State<RealtimeVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _amplitudes = List.generate(40, (_) => 0.1);
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_updateAmplitudes);
    
    if (widget.isPlaying) _controller.repeat();
  }

  void _updateAmplitudes() {
    if (!widget.isPlaying) return;
    
    setState(() {
      for (int i = 0; i < _amplitudes.length; i++) {
        // Create a wave effect combined with randomness
        double target = 0.2 + 0.6 * _random.nextDouble();
        // Smooth transition
        _amplitudes[i] = _amplitudes[i] * 0.7 + target * 0.3;
      }
    });
  }

  @override
  void didUpdateWidget(RealtimeVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
        _resetAmplitudes();
      }
    }
  }

  void _resetAmplitudes() {
    setState(() {
      for (int i = 0; i < _amplitudes.length; i++) {
        _amplitudes[i] = 0.05;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 80),
      painter: _VisualizerPainter(
        amplitudes: _amplitudes,
        color: widget.color,
      ),
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;

  _VisualizerPainter({required this.amplitudes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final double width = size.width;
    final double height = size.height;
    final double barWidth = width / amplitudes.length;

    for (int i = 0; i < amplitudes.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final barHeight = amplitudes[i] * height;
      
      final top = (height - barHeight) / 2;
      final bottom = (height + barHeight) / 2;

      // Draw glow
      canvas.drawLine(Offset(x, top), Offset(x, bottom), glowPaint);
      
      // Draw main bar
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter oldDelegate) => true;
}
