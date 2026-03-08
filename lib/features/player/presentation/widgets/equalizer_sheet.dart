
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/audio_effects_provider.dart';

class EqualizerSheet extends StatelessWidget {
  const EqualizerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final effects = context.watch<AudioEffectsProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: FlowyTheme.glassDecoration(
        borderRadius: 32,
        opacity: 0.15,
        tintColor: Colors.black,
        showShadow: true,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ecualizador',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Switch(
                value: effects.equalizerEnabled,
                onChanged: (_) => effects.toggleEqualizer(),
                activeColor: scheme.primary,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Presets
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: AudioEffectPresets.presets.keys.map((preset) {
                final isSelected = effects.currentPreset == preset;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(preset),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) effects.setPreset(preset);
                    },
                    backgroundColor: Colors.white10,
                    selectedColor: scheme.primary.withOpacity(0.3),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Bands
          Opacity(
            opacity: effects.equalizerEnabled ? 1.0 : 0.4,
            child: FutureBuilder<List<AndroidEqualizerBand>>(
              future: effects.handler.getEqualizerBands(),
              builder: (context, snapshot) {
                final bands = snapshot.data ?? [];
                if (bands.isEmpty) return const SizedBox(height: 180, child: Center(child: Text('No disponible', style: TextStyle(color: Colors.white24))));
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(bands.length, (index) {
                    final gain = effects.bandGains.length > index ? effects.bandGains[index] : 0.0;
                    // Android frequencies are usually in milliHertz (mHz).
                    // We detect based on the value magnitude.
                    final rawFreq = bands[index].centerFrequency;
                    final freqHz = rawFreq > 100000 ? (rawFreq / 1000).round() : rawFreq.round();
                    final label = freqHz >= 1000 ? '${(freqHz / 1000).toStringAsFixed(1)}k' : '${freqHz}Hz';
                    
                    return Column(
                      children: [
                        SizedBox(
                          height: 180,
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                activeTrackColor: scheme.primary,
                                inactiveTrackColor: Colors.white10,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: gain,
                                min: -10,
                                max: 10,
                                onChanged: effects.equalizerEnabled 
                                  ? (val) => effects.setBandGain(index, val)
                                  : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    );
                  }),
                );
              }
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Crossfade
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Crossfade',
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
              ),
              Text(
                '${effects.crossfadeDuration.toInt()}s',
                style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
              ),
            ],
          ),
          Slider(
            value: effects.crossfadeDuration,
            min: 0,
            max: 12,
            divisions: 12,
            label: '${effects.crossfadeDuration.toInt()}s',
            onChanged: (val) => effects.setCrossfade(val),
            activeColor: scheme.primary,
            inactiveColor: Colors.white10,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
