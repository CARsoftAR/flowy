import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'dart:io';
import 'package:flowy/core/constants/app_constants.dart';

class SplashPage extends StatefulWidget {
  final VoidCallback onFinish;

  const SplashPage({super.key, required this.onFinish});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
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
      backgroundColor: const Color(0xFF0D0D14),
      body: Stack(
        children: [
          // Background Gradient Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF4081).withOpacity(0.15),
              ),
            ).animate(onPlay: (c) => c.repeat()).scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.5, 1.5),
                  duration: 4.seconds,
                  curve: Curves.easeInOut,
                ).then().scale(
                  begin: const Offset(1.5, 1.5),
                  end: const Offset(1, 1),
                  duration: 4.seconds,
                  curve: Curves.easeInOut,
                ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C4DFF).withOpacity(0.15),
              ),
            ).animate(onPlay: (c) => c.repeat()).scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.3, 1.3),
                  duration: 3.seconds,
                  curve: Curves.easeInOut,
                ).then().scale(
                  begin: const Offset(1.3, 1.3),
                  end: const Offset(1, 1),
                  duration: 3.seconds,
                  curve: Curves.easeInOut,
                ),
          ),

          // Main Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Container with Glassmorphism
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.music_note_rounded,
                            size: 80,
                            color: Colors.white.withOpacity(0.9),
                          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds, color: const Color(0xFFFF4081).withOpacity(0.4)),
                          
                          // Pulsing Rings
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white10, width: 1),
                            ),
                          ).animate(onPlay: (c) => c.repeat()).scale(
                                begin: const Offset(1, 1),
                                end: const Offset(1.5, 1.5),
                                duration: 2.seconds,
                              ).fadeOut(),

                           Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white10, width: 1),
                            ),
                          ).animate(onPlay: (c) => c.repeat()).scale(
                                begin: const Offset(1, 1),
                                end: const Offset(1.8, 1.8),
                                delay: 500.ms,
                                duration: 2.seconds,
                              ).fadeOut(),
                        ],
                      ),
                    ),
                  ),
                ).animate()
                  .scale(duration: 800.ms, curve: Curves.easeOutBack)
                  .shimmer(delay: 1.seconds, duration: 1500.ms, color: Colors.white24),

                const SizedBox(height: 32),

                // App Name with Premium Typography
                Text(
                   AppConstants.appName,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: const Color(0xFFFF4081).withOpacity(0.5),
                        blurRadius: 15,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                ).animate()
                  .fadeIn(delay: 400.ms, duration: 800.ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOutQuad),

                const SizedBox(height: 8),

                // Tagline
                Text(
                  'SIENTE EL SONIDO',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white38,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w300,
                  ),
                ).animate()
                  .fadeIn(delay: 800.ms, duration: 1000.ms),
              ],
            ),
          ),

          // Loading indicator at bottom
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 40,
                height: 2,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFFFF4081).withOpacity(0.8),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 1200.ms),
          ),
        ],
      ),
    );
  }
}
