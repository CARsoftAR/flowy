
import 'dart:async';
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

  bool _equalizerEnabled = true;
  List<double> _bandGains = [0, 0, 0, 0, 0];
  String _currentPreset = 'Plano';
  
  bool _autoEqEnabled = true;
  List<dynamic> _bands = [];
  StreamSubscription? _mediaSubscription;

  // Crossfade (in seconds)
  double _crossfadeDuration = 0.0;

  AudioEffectsProvider({required FlowyAudioHandler handler}) : _handler = handler {
    _init();
  }

  Future<void> _init() async {
    final fetchedBands = await _handler.getEqualizerBands();
    _bands = fetchedBands;
    
    if (_bands.isNotEmpty) {
      _bandGains = List.generate(_bands.length, (_) => 0.0);
    }
    
    await _handler.setEqualizerEnabled(_equalizerEnabled);

    // Initial check for current song if already playing
    final initialMedia = _handler.mediaItem.value;
    if (_autoEqEnabled && initialMedia != null) {
      _applyAutoEq(initialMedia.title, initialMedia.artist ?? '');
    }

    // Listen for media changes to apply Auto-EQ
    _mediaSubscription = _handler.mediaItem.listen((item) {
      if (_autoEqEnabled && item != null) {
        _applyAutoEq(item.title, item.artist ?? '');
      }
    });

    notifyListeners();
  }

  @override
  void dispose() {
    _mediaSubscription?.cancel();
    super.dispose();
  }

  FlowyAudioHandler get handler => _handler;
  bool get equalizerEnabled => _equalizerEnabled;
  bool get autoEqEnabled => _autoEqEnabled;
  List<double> get bandGains => _bandGains;
  List<dynamic> get bands => _bands;
  String get currentPreset => _currentPreset;
  double get crossfadeDuration => _crossfadeDuration;

  Future<void> toggleEqualizer() async {
    _equalizerEnabled = !_equalizerEnabled;
    await _handler.setEqualizerEnabled(_equalizerEnabled);
    notifyListeners();
  }

  Future<void> toggleAutoEq() async {
    _autoEqEnabled = !_autoEqEnabled;
    if (_autoEqEnabled) {
      // Si se activa, forzar una actualización con el tema actual
      final current = _handler.mediaItem.value;
      if (current != null) {
        _applyAutoEq(current.title, current.artist ?? '');
      }
    }
    notifyListeners();
  }

  void _applyAutoEq(String title, String artist) {
    if (!_equalizerEnabled) {
      _equalizerEnabled = true;
      _handler.setEqualizerEnabled(true);
    }

    final text = '$title $artist'.toLowerCase();
    
    if (text.contains('podcast') || 
        text.contains('charla') || 
        text.contains('entrevista') || 
        text.contains('hablando') ||
        text.contains('audiobook') ||
        text.contains('libro') || 
        text.contains('conversación')) {
      setPreset('Vocal');
    } else if (text.contains('techno') || 
               text.contains('house') || 
               text.contains('electro') || 
               text.contains('reggaeton') || 
               text.contains('trap') || 
               text.contains('dance') ||
               text.contains('remix') ||
               text.contains('bass') ||
               text.contains('urbano') ||
               text.contains('dembow') ||
               text.contains('perreo') ||
               text.contains('flow')) {
      setPreset('Bass Boost');
    } else if (text.contains('rock') || 
               text.contains('metal') || 
               text.contains('heavy') || 
               text.contains('punk') || 
               text.contains('guitar') || 
               text.contains('band') || 
               text.contains('indie') || 
               text.contains('alternative') || 
               text.contains('grunge')) {
      setPreset('Rock');
    } else if (text.contains('pop') || text.contains('hit') || text.contains('top') || text.contains('radio')) {
      setPreset('Pop');
    } else if (text.contains('jazz') || text.contains('blues') || text.contains('soul') || text.contains('sax')) {
      setPreset('Jazz');
    } else if (text.contains('clásica') || 
               text.contains('classic') || 
               text.contains('instrumental') || 
               text.contains('acustico') || 
               text.contains('acoustic') ||
               text.contains('piano') ||
               text.contains('violin')) {
      setPreset('Clásica');
    } else {
      // Por defecto para música general si no detectamos nada específico
      setPreset('Pop'); 
    }
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
