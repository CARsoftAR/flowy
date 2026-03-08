import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum AudioCategory { music, audiobooks, podcasts }

class InterestEntity {
  final String id;
  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final AudioCategory category;
  final String searchQuerySuffix;

  const InterestEntity({
    required this.id,
    required this.title,
    required this.icon,
    required this.gradientColors,
    required this.category,
    required this.searchQuerySuffix,
  });
}

class CategoryData {
  static const List<InterestEntity> musicInterests = [
    InterestEntity(
      id: 'rock',
      title: 'Rock',
      icon: Icons.electric_bolt_rounded,
      gradientColors: [Color(0xFFFF512F), Color(0xFFDD2476)],
      category: AudioCategory.music,
      searchQuerySuffix: 'rock music',
    ),
    InterestEntity(
      id: 'pop',
      title: 'Pop',
      icon: Icons.auto_awesome_rounded,
      gradientColors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      category: AudioCategory.music,
      searchQuerySuffix: 'pop music',
    ),
    InterestEntity(
      id: 'lofi',
      title: 'Lo-Fi',
      icon: Icons.cloud_rounded,
      gradientColors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
      category: AudioCategory.music,
      searchQuerySuffix: 'lofi hip hop',
    ),
    InterestEntity(
      id: 'jazz',
      title: 'Jazz',
      icon: Icons.curtains_rounded,
      gradientColors: [Color(0xFF232526), Color(0xFF414345)],
      category: AudioCategory.music,
      searchQuerySuffix: 'jazz classics',
    ),
    InterestEntity(
      id: 'classical',
      title: 'Clásica',
      icon: Icons.music_note_rounded,
      gradientColors: [Color(0xFFDAE2F8), Color(0xFFD6A4A4)],
      category: AudioCategory.music,
      searchQuerySuffix: 'classical music orchestra',
    ),
  ];

  static const List<InterestEntity> audiobookInterests = [
    InterestEntity(
      id: 'mystery',
      title: 'Misterio',
      icon: FontAwesomeIcons.magnifyingGlass,
      gradientColors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
      category: AudioCategory.audiobooks,
      searchQuerySuffix: 'audiolibro misterio completo',
    ),
    InterestEntity(
      id: 'terror_fiction',
      title: 'Relatos de Terror',
      icon: FontAwesomeIcons.skull,
      gradientColors: [Color(0xFF000000), Color(0xFF434343)],
      category: AudioCategory.audiobooks,
      searchQuerySuffix: 'audiolibro relatos de terror español',
    ),
    InterestEntity(
      id: 'fiction',
      title: 'Ficción',
      icon: Icons.menu_book_rounded,
      gradientColors: [Color(0xFF11998e), Color(0xFF38ef7d)],
      category: AudioCategory.audiobooks,
      searchQuerySuffix: 'audiolibro completo ficción',
    ),
    InterestEntity(
      id: 'personal_dev',
      title: 'Desarrollo Personal',
      icon: Icons.psychology_rounded,
      gradientColors: [Color(0xFFF2994A), Color(0xFFF2C94C)],
      category: AudioCategory.audiobooks,
      searchQuerySuffix: 'audiolibro desarrollo personal',
    ),
    InterestEntity(
      id: 'history_books',
      title: 'Historia',
      icon: Icons.account_balance_rounded,
      gradientColors: [Color(0xFF4b6cb7), Color(0xFF182848)],
      category: AudioCategory.audiobooks,
      searchQuerySuffix: 'audiolibro historia completa',
    ),
    InterestEntity(
      id: 'finance_books',
      title: 'Finanzas',
      icon: Icons.payments_rounded,
      gradientColors: [Color(0xFF1D976C), Color(0xFF93F9B9)],
      category: AudioCategory.audiobooks,
      searchQuerySuffix: 'audiolibro finanzas y dinero',
    ),
  ];

  static const List<InterestEntity> podcastInterests = [
    // --- Misterio y Paranormal ---
    InterestEntity(
      id: 'paranormal',
      title: 'Paranormal',
      icon: FontAwesomeIcons.ghost,
      gradientColors: [Color(0xFF141E30), Color(0xFF243B55)],
      category: AudioCategory.podcasts,
      searchQuerySuffix: 'podcast paranormal español',
    ),
    InterestEntity(
      id: 'ghosts',
      title: 'Fantasmas',
      icon: FontAwesomeIcons.ghost,
      gradientColors: [Color(0xFF000000), Color(0xFF533483)],
      category: AudioCategory.podcasts,
      searchQuerySuffix: 'podcast historias de fantasmas',
    ),
    InterestEntity(
      id: 'spirits',
      title: 'Espíritus',
      icon: FontAwesomeIcons.fire,
      gradientColors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
      category: AudioCategory.podcasts,
      searchQuerySuffix: 'podcast espíritus y aparecidos',
    ),
    InterestEntity(
      id: 'urban_legends',
      title: 'Leyendas Urbanas',
      icon: FontAwesomeIcons.city,
      gradientColors: [Color(0xFF200122), Color(0xFF6f0000)],
      category: AudioCategory.podcasts,
      searchQuerySuffix: 'podcast leyendas urbanas',
    ),
    InterestEntity(
      id: 'inexplicable',
      title: 'Casos Inexplicables',
      icon: FontAwesomeIcons.question,
      gradientColors: [Color(0xFF000000), Color(0xFF0f9b0f)],
      category: AudioCategory.podcasts,
      searchQuerySuffix: 'podcast casos inexplicables',
    ),
    
    // --- Otras Categorías ---
    InterestEntity(
      id: 'science',
      title: 'Ciencia',
      icon: FontAwesomeIcons.flask,
      gradientColors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
      category: AudioCategory.podcasts,
      searchQuerySuffix: 'podcast ciencia',
    ),
    InterestEntity(
      id: 'entrepreneur',
      title: 'Emprendimiento',
      icon: FontAwesomeIcons.lightbulb,
      gradientColors: [Color(0xFFf12711), Color(0xFFf5af19)],
      category: AudioCategory.podcasts,
      searchQuerySuffix: 'podcast emprendimiento',
    ),
    InterestEntity(
      id: 'geek_culture',
      title: 'Cultura Geek',
      icon: FontAwesomeIcons.gamepad,
      gradientColors: [Color(0xFF1e3c72), Color(0xFF2a5298)],
      category: AudioCategory.podcasts,
      searchQuerySuffix: 'podcast cultura geek',
    ),
    InterestEntity(
      id: 'tech',
      title: 'Tecnología',
      icon: Icons.terminal_rounded,
      gradientColors: [Color(0xFF232526), Color(0xFF414345)],
      category: AudioCategory.podcasts,
      searchQuerySuffix: 'podcast tecnología',
    ),
    InterestEntity(
      id: 'true_crime',
      title: 'Crimen Real',
      icon: Icons.gavel_rounded,
      gradientColors: [Color(0xFF870000), Color(0xFF190A05)],
      category: AudioCategory.podcasts,
      searchQuerySuffix: 'podcast crimen real',
    ),
    InterestEntity(
      id: 'mental_health',
      title: 'Salud Mental',
      icon: Icons.favorite_rounded,
      gradientColors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
      category: AudioCategory.podcasts,
      searchQuerySuffix: 'podcast salud mental',
    ),
    InterestEntity(
      id: 'movies',
      title: 'Cine y TV',
      icon: FontAwesomeIcons.film,
      gradientColors: [Color(0xFFe52d27), Color(0xFFb31217)],
      category: AudioCategory.podcasts,
      searchQuerySuffix: 'podcast cine y series',
    ),
    InterestEntity(
      id: 'languages',
      title: 'Idiomas',
      icon: FontAwesomeIcons.language,
      gradientColors: [Color(0xFF4CA1AF), Color(0xFFC4E0E5)],
      category: AudioCategory.podcasts,
      searchQuerySuffix: 'podcast aprender idiomas',
    ),
    InterestEntity(
      id: 'sports',
      title: 'Deportes',
      icon: FontAwesomeIcons.volleyball,
      gradientColors: [Color(0xFF11998e), Color(0xFF38ef7d)],
      category: AudioCategory.podcasts,
      searchQuerySuffix: 'podcast deportes',
    ),
    InterestEntity(
      id: 'news',
      title: 'Noticias',
      icon: FontAwesomeIcons.newspaper,
      gradientColors: [Color(0xFF2c3e50), Color(0xFF4ca1af)],
      category: AudioCategory.podcasts,
      searchQuerySuffix: 'podcast noticias actualidad',
    ),
  ];

  static List<InterestEntity> getInterestsForCategory(AudioCategory category) {
    switch (category) {
      case AudioCategory.music:
        return musicInterests;
      case AudioCategory.audiobooks:
        return audiobookInterests;
      case AudioCategory.podcasts:
        return podcastInterests;
    }
  }
}
