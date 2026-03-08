
import 'package:flutter/foundation.dart';
import '../../../../data/datasources/audio_handler.dart';

class AudioEffectPresets {
  static const Map<String, List<double>> presets = {
    'Plano': [0, 0, 0, 0, 0],
    'Pop': [1.5, 3.0, 4.5, 1.5, -1.5],
    'Rock': [4.5, 1.5, -3.0, 1.5, 4.5],
    'Jazz': [3.0, 0, 0, 1.5, 3.0],
    'Clásica': [4.5, 3.0, -1.5, 3.0, 4.5],
    'Bass Boost': [6.0, 3.0, 0, 0, 0],
    'Vocal': [-1.5, 1.5, 4.5, 3.0, 0],
  };
}

class AudioEffectsProvider extends ChangeNotifier {
  final FlowyAudioHandler _handler;

  bool _equalizerEnabled = false;
  List<double> _bandGains = [0, 0, 0, 0, 0];
  String _currentPreset = 'Plano';
  
  // Crossfade (in seconds)
  double _crossfadeDuration = 0.0;

  AudioEffectsProvider({required FlowyAudioHandler handler}) : _handler = handler {
    _init();
  }

  Future<void> _init() async {
    await _handler.setEqualizerEnabled(_equalizerEnabled);
    final bands = await _handler.getEqualizerBands();
    if (bands.isNotEmpty) {
      _bandGains = List.generate(bands.length, (_) => 0.0);
      notifyListeners();
    }
  }

  FlowyAudioHandler get handler => _handler;
  bool get equalizerEnabled => _equalizerEnabled;
  List<double> get bandGains => _bandGains;
  String get currentPreset => _currentPreset;
  double get crossfadeDuration => _crossfadeDuration;

  Future<void> toggleEqualizer() async {
    _equalizerEnabled = !_equalizerEnabled;
    await _handler.setEqualizerEnabled(_equalizerEnabled);
    notifyListeners();
  }

  Future<void> setBandGain(int index, double gain) async {
    if (index >= 0 && index < _bandGains.length) {
      _bandGains[index] = gain;
      _currentPreset = 'Custom';
      await _handler.setEqualizerBandGain(index, gain);
      notifyListeners();
    }
  }

  Future<void> setPreset(String name) async {
    if (AudioEffectPresets.presets.containsKey(name)) {
      _currentPreset = name;
      final presetGains = AudioEffectPresets.presets[name]!;
      
      // Map preset gains to available bands (usually 5, but we check)
      for (int i = 0; i < _bandGains.length; i++) {
        if (i < presetGains.length) {
          _bandGains[i] = presetGains[i];
        } else {
          _bandGains[i] = 0.0; // Fallback for extra bands
        }
        await _handler.setEqualizerBandGain(i, _bandGains[i]);
      }
      notifyListeners();
    }
  }

  void setCrossfade(double duration) {
    _crossfadeDuration = duration;
    _handler.setCrossfade(duration);
    notifyListeners();
  }
}
