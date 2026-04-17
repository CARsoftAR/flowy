import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AudioLoadingOverlay extends StatelessWidget {
  const AudioLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF161625),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF7C4DFF)),
                    ),
                  ),
                ],
              ),
            ).animate().scale(begin: const Offset(0.8, 0.8)).fadeIn(),
          ],
        ),
      ),
    );
  }
}
