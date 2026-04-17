import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';

class VolumeSheet extends StatelessWidget {
  const VolumeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 40,
            offset: const Offset(0, -10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            'Volumen',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Icon(
                player.volume == 0 
                    ? Icons.volume_off_rounded 
                    : player.volume < 0.5 
                        ? Icons.volume_down_rounded 
                        : Icons.volume_up_rounded,
                color: Colors.white70,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 6,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                    activeTrackColor: scheme.primary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: player.volume,
                    onChanged: (value) => player.setVolume(value),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 45,
                child: Text(
                  '${(player.volume * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
