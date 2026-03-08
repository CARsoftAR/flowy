import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/audio_handler.dart';
import 'data/repositories/music_repository_impl.dart';
import 'domain/repositories/repositories.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/library/presentation/pages/library_page.dart';
import 'features/library/presentation/providers/library_provider.dart';
import 'features/library/presentation/providers/download_provider.dart';
import 'features/player/presentation/providers/player_provider.dart';
import 'features/player/presentation/providers/audio_effects_provider.dart';
import 'features/player/presentation/providers/sleep_timer_provider.dart';
import 'features/player/presentation/widgets/mini_player.dart';
import 'features/search/presentation/pages/search_page.dart';
import 'features/search/presentation/providers/search_history_provider.dart';
import 'features/splash/presentation/pages/splash_page.dart';
import 'core/theme/ambient_background.dart';
import 'core/widgets/loading_overlay.dart';
import 'domain/entities/entities.dart';

// ─────────────────────────────────────────────────────────────────────────────
// main.dart — App entry point
// ─────────────────────────────────────────────────────────────────────────────

Future<void> main() async {
  // Capture all Flutter framework errors
  FlutterError.onError = FlutterError.presentError;

  await runZonedGuarded(_init, (error, stack) {
    // Last-resort: show error screen instead of black screen
    runApp(_ErrorApp(message: error.toString()));
  });
}

Future<void> _init() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── System UI ────────────────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── flutter_animate global settings ─────────────────────────────────────
  Animate.restartOnHotReload = true;

  // ── Initialize audio_service ─────────────────────────────────────────────
  final musicRepo = MusicRepositoryImpl();
  final prefs = await SharedPreferences.getInstance();

  final audioHandler = await AudioService.init<FlowyAudioHandler>(
    builder: () => FlowyAudioHandler(
      musicRepository: musicRepo,
      sharedPreferences: prefs,
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.flowy.audio.channel',
      androidNotificationChannelName: 'Flowy Music',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      notificationColor: Color(0xFF7C4DFF),
    ),
  );

  // ── Dependency injection ─────────────────────────────────────────────────
  await configureDependencies(audioHandler: audioHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayerProvider>(
          create: (_) => sl<PlayerProvider>(),
        ),
        ChangeNotifierProvider<LibraryProvider>(
          create: (_) => LibraryProvider(prefs),
        ),
        ChangeNotifierProvider<DownloadProvider>(
          create: (_) => DownloadProvider(),
        ),
        ChangeNotifierProvider<SearchHistoryProvider>(
          create: (_) => SearchHistoryProvider(),
        ),
        ChangeNotifierProvider<AudioEffectsProvider>(
          create: (_) => AudioEffectsProvider(handler: sl<FlowyAudioHandler>()),
        ),
        ChangeNotifierProvider<SleepTimerProvider>(
          create: (_) => SleepTimerProvider(sl<FlowyAudioHandler>()),
        ),
      ],
      child: const FlowyApp(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _ErrorApp — Fallback shown when initialization crashes
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 64, color: Color(0xFFFF5C7C)),
                const SizedBox(height: 16),
                const Text(
                  'Flowy',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ocurrió un error al iniciar',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    message,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white54, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FlowyApp — Root widget with DynamicColorBuilder
// ─────────────────────────────────────────────────────────────────────────────

class FlowyApp extends StatefulWidget {
  const FlowyApp({super.key});

  @override
  State<FlowyApp> createState() => _FlowyAppState();
}

class _FlowyAppState extends State<FlowyApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightScheme, darkScheme) {
        // Fallback for dark scheme if dynamic not available
        final darkColorScheme = darkScheme ??
            ColorScheme.fromSeed(
              seedColor: FlowyColors.brandSeed,
              brightness: Brightness.dark,
            );

        // Fallback for light scheme if dynamic not available
        final lightColorScheme = lightScheme ??
            ColorScheme.fromSeed(
              seedColor: FlowyColors.brandSeed,
              brightness: Brightness.light,
            );

        return MaterialApp(
          title: 'Flowy',
          debugShowCheckedModeBanner: false,
          theme: FlowyTheme.buildTheme(colorScheme: lightColorScheme),
          darkTheme: FlowyTheme.buildTheme(colorScheme: darkColorScheme),
          themeMode: ThemeMode.dark, // Default to dark since it's a music app
          home: _showSplash
              ? SplashPage(onFinish: () => setState(() => _showSplash = false))
              : const FlowyShell(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FlowyShell — Scaffold with NavigationBar + MiniPlayer overlay
// ─────────────────────────────────────────────────────────────────────────────

class FlowyShell extends StatefulWidget {
  const FlowyShell({super.key});

  @override
  State<FlowyShell> createState() => _FlowyShellState();
}

class _FlowyShellState extends State<FlowyShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    SearchPage(),
    LibraryPage(),
  ];

  @override
  Widget build(BuildContext context) {
    // Listen for sync events from the Player (coming from Notification)
    final player = context.read<PlayerProvider>();
    final library = context.read<LibraryProvider>();
    
    player.addListener(() {
      // If the player status changed or a custom event happened, refresh library
      library.refreshData();

      // Handle Resume Request
      if (player.resumeRequest != null && mounted) {
        final request = player.resumeRequest!;
        player.clearResumeRequest(); // Clear so it doesn't show again
        
        _showResumeDialog(context, player, request);
      }
    });

    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        return Scaffold(
          backgroundColor: FlowyColors.surface,
          body: AmbientBackground(
            imageUrl: player.currentSong?.bestThumbnail,
            overlayOpacity: 0.7,
            child: Stack(
              children: [
                // ── Pages ───────────────────────────────────────────────────────
                IndexedStack(
                  index: _selectedIndex,
                  children: _pages,
                ),

                // ── MiniPlayer ──────────────────────────────────────────────────
                Positioned(
                  bottom: AppConstants.navBarHeight + 4,
                  left: 0,
                  right: 0,
                  child: const MiniPlayer(),
                ),

                // ── Loading Overlay ──────────────────────────────────────────────
                if (player.isLoading)
                  const AudioLoadingOverlay(),
              ],
            ),
          ),

          // ── NavigationBar ───────────────────────────────────────────────────
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search_rounded),
                label: 'Buscar',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music_rounded),
                label: 'Biblioteca',
              ),
            ],
          ),
        );
      },
    );
  }

  void _showResumeDialog(BuildContext context, PlayerProvider player, Map<String, dynamic> request) {
    final seconds = request['seconds'] as int;
    final mins = seconds ~/ 60;
    final secs = (seconds % 60).toString().padLeft(2, '0');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161625),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Continuar escuchando', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Hemos guardado tu progreso en "${request['title']}". ¿Quieres retomarlo desde el minuto $mins:$secs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Desde el inicio', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () {
              player.seekTo(Duration(seconds: seconds));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}

// _AmbientGlowPainter was removed in favor of AmbientBackground widget
