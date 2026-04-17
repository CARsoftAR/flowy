import 'package:flutter/material.dart';

class RadioStation {
  final String id;
  final String name;
  final String genre;
  final String streamUrl;
  final String? thumbnailUrl;
  final List<Color> gradientColors;
  final IconData icon;

  const RadioStation({
    required this.id,
    required this.name,
    required this.genre,
    required this.streamUrl,
    this.thumbnailUrl,
    this.gradientColors = const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    this.icon = Icons.radio,
  });
}

class RadioStations {
  static const List<RadioStation> predefined = [];
}
