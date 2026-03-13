import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'package:flowy/core/constants/app_constants.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashPage extends StatefulWidget {
  final VoidCallback onFinish;

  const SplashPage({super.key, required this.onFinish});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _startTransition();
  }

  void _startTransition() async {
    await Future.delayed(const Duration(milliseconds: 3500));
    if (mounted) {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: size.width * 0.9,
          child: Image.asset(
            'assets/fondo_final.png',
            fit: BoxFit.contain,
          ),
        ).animate()
          .fadeIn(duration: 800.ms)
          .scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1, 1),
            duration: 1200.ms,
            curve: Curves.easeOutCubic,
          ),
      ),
    );
  }
}
