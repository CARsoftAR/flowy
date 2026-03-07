class AppConstants {
  AppConstants._();

  static const String appName = 'TitiSonics';
  static const String appVersion = '1.0.0';

  // Cache
  static const Duration cacheTtl = Duration(hours: 6);
  static const int maxCacheSize = 200; // MB
  static const int preloadNextTracks = 2;

  // Audio
  static const Duration skipDuration = Duration(seconds: 10);
  static const int maxSearchSuggestions = 8;
  static const int searchDebounceMs = 350;
  static const int historyMaxItems = 50;

  // UI
  static const double miniPlayerHeight = 72.0;
  static const double navBarHeight = 70.0;
  static const double playerArtworkSize = 320.0;
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 350);
  static const Duration animationSlow = Duration(milliseconds: 600);

  // YouTube
  static const String ytMusicUrl = 'https://music.youtube.com';
  static const String ytBaseUrl = 'https://www.youtube.com';
}
