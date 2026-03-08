
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../data/datasources/audio_handler.dart';

class SleepTimerProvider extends ChangeNotifier {
  final FlowyAudioHandler _handler;
  Timer? _timer;
  int? _remainingMinutes;
  int? _selectedMinutes;

  SleepTimerProvider(this._handler);

  int? get remainingMinutes => _remainingMinutes;
  int? get selectedMinutes => _selectedMinutes;
  bool get isActive => _timer != null;

  void setTimer(int minutes) {
    cancelTimer();
    _selectedMinutes = minutes;
    _remainingMinutes = minutes;
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_remainingMinutes == null) {
        cancelTimer();
        return;
      }
      _remainingMinutes = _remainingMinutes! - 1;
      if (_remainingMinutes! <= 0) {
        _handler.pause();
        cancelTimer();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _remainingMinutes = null;
    _selectedMinutes = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
