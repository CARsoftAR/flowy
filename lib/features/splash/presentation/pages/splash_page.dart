import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flowy/core/constants/app_constants.dart';
import 'package:flowy/core/theme/ambient_background.dart';
import '../../../../core/theme/app_theme.dart';

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
    await Future.delayed(const Duration(milliseconds: 3000));
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
      body: AmbientBackground(
        dominantColor: const Color(0xFF041C2C), // Matching the dark teal from the new image
        child: Stack(
          children: [
            // ── Main Splash Image with Soft Blending ────────────────────
            Positioned.fill(
              child: Center(
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return RadialGradient(
                      center: Alignment.center,
                      radius: 1.8, // Radio mucho mayor para cubrir el ancho de un logo horizontal
                      colors: [
                        Colors.black,
                        Colors.black.withOpacity(0.0),
                      ],
                      stops: const [0.8, 1.0], // Mantiene total opacidad en casi todo el logo
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'assets/flowy_elephant.png',
                      width: size.width * 0.7, // Aumentado para dar espacio al texto FLOWY
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ).animate()
             .fadeIn(duration: 1500.ms)
             .scale(begin: const Offset(1.05, 1.05), duration: 2500.ms, curve: Curves.easeOutCubic),

            // ── Overlay Accents ──────────────────────────────────────────
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Minimalistic Loading Progress
                    SizedBox(
                      width: 180,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        color: FlowyColors.brandAccent.withOpacity(0.4),
                        minHeight: 1,
                      ),
                    ).animate().fadeIn(delay: 1200.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

