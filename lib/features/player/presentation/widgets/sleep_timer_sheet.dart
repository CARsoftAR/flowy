
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sleep_timer_provider.dart';

class SleepTimerSheet extends StatelessWidget {
  const SleepTimerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<SleepTimerProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161625), // Solid background, no transparency
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.timer_rounded, color: scheme.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Text(
                  'Temporizador de Apagado',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Grid of options
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [5, 15, 30, 45, 60, 90].map((mins) {
                // Determine if this specific option is the active one
                final isSelected = timer.isActive && timer.selectedMinutes == mins;
                
                return GestureDetector(
                  onTap: () => timer.setTimer(mins),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: (MediaQuery.of(context).size.width - 72) / 3,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isSelected ? scheme.primary : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? scheme.primary : Colors.white10,
                        width: 1.5,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: scheme.primary.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ] : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          mins.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'min',
                          style: TextStyle(
                            color: isSelected ? Colors.white.withOpacity(0.8) : Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            
            if (timer.isActive) ...[
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Se apagará en aproximadamente ${timer.remainingMinutes} min',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => timer.cancelTimer(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.error.withOpacity(0.1),
                  foregroundColor: scheme.error,
                  minimumSize: const Size(double.infinity, 56),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Desactivar Temporizador'),
              ),
            ],
            
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
