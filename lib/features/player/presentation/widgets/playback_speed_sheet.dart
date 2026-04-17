import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';

class PlaybackSpeedSheet extends StatelessWidget {
  const PlaybackSpeedSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final currentSpeed = player.playbackSpeed;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFF0D0D14), // Solid dark background 
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 40,
            offset: Offset(0, -10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            'Velocidad de Reproducción',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: speeds.map((speed) {
              final isSelected = (speed - currentSpeed).abs() < 0.01;
              return ChoiceChip(
                label: Text('${speed}x'),
                selected: isSelected,
                onSelected: (val) {
                  if (val) {
                    player.setPlaybackSpeed(speed);
                    Navigator.pop(context);
                  }
                },
                selectedColor: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.3),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : scheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
