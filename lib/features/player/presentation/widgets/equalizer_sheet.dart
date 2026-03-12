
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:google_fonts/google_fonts.dart';
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
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D14), // Solid dark background as requested
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
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
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Switch(
                value: effects.equalizerEnabled,
                onChanged: (_) => effects.toggleEqualizer(),
                activeColor: scheme.primary,
                activeTrackColor: scheme.primary.withOpacity(0.3),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Presets
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: AudioEffectPresets.presets.keys.map((preset) {
                final isSelected = effects.currentPreset == preset;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: ChoiceChip(
                      label: Text(preset),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) effects.setPreset(preset);
                      },
                      backgroundColor: Colors.white.withOpacity(0.05),
                      selectedColor: scheme.primary,
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white60,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
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
                
                // If bands empty, we show 5 default placeholders that simulate real bands
                // to avoid "No disponible" when it's just initializing
                final displayCount = bands.isEmpty ? 5 : bands.length;
                
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(displayCount, (index) {
                        final gain = effects.bandGains.length > index ? effects.bandGains[index] : 0.0;
                        
                        String label = '';
                        if (bands.isNotEmpty) {
                          final rawFreq = bands[index].centerFrequency;
                          final freqHz = rawFreq > 100000 ? (rawFreq / 1000).round() : rawFreq.round();
                          label = freqHz >= 1000 ? '${(freqHz / 1000).toStringAsFixed(1)}k' : '${freqHz}Hz';
                        } else {
                          // Fallback labels
                          label = ['60', '230', '910', '3k', '14k'][index];
                        }
                        
                        return Column(
                          children: [
                            Text(
                              '${gain.toInt() > 0 ? "+" : ""}${gain.toInt()}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: effects.equalizerEnabled ? scheme.primary : Colors.white24,
                                fontWeight: FontWeight.bold,
                                fontSize: 10
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 180,
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                    activeTrackColor: scheme.primary,
                                    inactiveTrackColor: Colors.white10,
                                    thumbColor: Colors.white,
                                    trackShape: const RoundedRectSliderTrackShape(),
                                  ),
                                  child: Slider(
                                    value: gain,
                                    min: -15, // Increased range
                                    max: 15,
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
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: effects.equalizerEnabled ? Colors.white70 : Colors.white24, 
                                fontSize: 10
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                    if (bands.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Cargando parámetros de audio...',
                          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.1)),
                        ),
                      ),
                  ],
                );
              }
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Crossfade
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Crossfade (Transición)',
                      style: theme.textTheme.titleSmall?.copyWith(color: Colors.white60),
                    ),
                    Text(
                      '${effects.crossfadeDuration.toInt()}s',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: effects.crossfadeDuration,
                  min: 0,
                  max: 12,
                  divisions: 12,
                  onChanged: (val) => effects.setCrossfade(val),
                  activeColor: scheme.primary,
                  inactiveColor: Colors.white10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
