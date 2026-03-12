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
      backgroundColor: const Color(0xFF1C2131), // Background matching the image
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Animated Ambient Background ─────────────────────────────────────
          _AmbientBlob(
            color: const Color(0xFF323F5F).withOpacity(0.4),
            size: size.width * 1.2,
            offset: const Offset(-0.5, -0.3),
            duration: 8.seconds,
          ),
          _AmbientBlob(
            color: const Color(0xFF1E2638).withOpacity(0.3),
            size: size.width * 1.0,
            offset: const Offset(0.6, 0.4),
            duration: 10.seconds,
          ),
          _AmbientBlob(
            color: const Color(0xFF2D3748).withOpacity(0.2),
            size: size.width * 0.8,
            offset: const Offset(-0.2, 0.6),
            duration: 7.seconds,
          ),
          
          // Blur layer to create the liquid mesh effect
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),

          // Noise texture overlay
          Opacity(
            opacity: 0.04,
            child: Image.network(
              'https://grainy-gradients.vercel.app/noise.svg',
              fit: BoxFit.cover,
            ),
          ),

          // ── Center Content ──────────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Abstract Logo
                Container(
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer glow
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1C2131).withOpacity(0.5),
                              blurRadius: 50,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 2.seconds),

                      // Logo Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(90),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ).animate()
                  .scale(duration: 1500.ms, curve: Curves.easeOutQuart)
                  .fadeIn(duration: 1.seconds),

                const SizedBox(height: 24),

                // App Name "FLOWY"
                Text(
                  'Flowy',
                  style: GoogleFonts.outfit(
                    textStyle: const TextStyle(
                      fontSize: 52, 
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      color: Colors.white,
                    ),
                  ),
                ).animate()
                  .fadeIn(delay: 500.ms, duration: 1.seconds)
                  .slideY(begin: 0.1, end: 0, duration: 800.ms, curve: Curves.easeOutQuart),

                const SizedBox(height: 8),

                // Premium Tagline
                Text(
                  'PURE AUDIO BLISS',
                  style: GoogleFonts.lexend(
                    textStyle: const TextStyle(
                      fontSize: 10,
                      color: Colors.white30,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ).animate()
                  .fadeIn(delay: 1200.ms, duration: 1.seconds),
              ],
            ),
          ),

          // ── Bottom Loading Indicator ───────────────────────────────────────
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 160,
                    height: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white24),
                      ),
                    ),
                  ).animate()
                    .fadeIn(delay: 1500.ms)
                    .scaleX(begin: 0, end: 1, duration: 1800.ms),
                  const SizedBox(height: 12),
                  Text(
                    'INITIALIZING FLOWY ENGINE',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      color: Colors.white10,
                      letterSpacing: 2,
                    ),
                  ).animate().fadeIn(delay: 1800.ms),
                ],
              ),
            ),
          ),
        ],
      ),

    );
  }
}

class _AmbientBlob extends StatelessWidget {
  final Color color;
  final double size;
  final Offset offset;
  final Duration duration;

  const _AmbientBlob({
    required this.color,
    required this.size,
    required this.offset,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: MediaQuery.of(context).size.width * (0.5 + offset.dx) - size / 2,
      top: MediaQuery.of(context).size.height * (0.5 + offset.dy) - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true))
        .move(begin: const Offset(-20, -30), end: const Offset(30, 20), duration: duration, curve: Curves.easeInOut)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: duration, curve: Curves.easeInOut),
    );
  }
}
