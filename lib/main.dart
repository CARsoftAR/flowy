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
import 'features/player/presentation/providers/player_provider.dart';
import 'features/player/presentation/widgets/mini_player.dart';
import 'features/search/presentation/pages/search_page.dart';
import 'features/splash/presentation/pages/splash_page.dart';

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

  final audioHandler = await AudioService.init<FlowyAudioHandler>(
    builder: () => FlowyAudioHandler(musicRepository: musicRepo),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.flowy.audio.channel',
      androidNotificationChannelName: 'TitiSonics Music',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      notificationColor: Color(0xFF7C4DFF),
    ),
  );

  final prefs = await SharedPreferences.getInstance();

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
      ],
      child: const TitiSonicsApp(),
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
                  'TitiSonics',
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

class TitiSonicsApp extends StatefulWidget {
  const TitiSonicsApp({super.key});

  @override
  State<TitiSonicsApp> createState() => _TitiSonicsAppState();
}

class _TitiSonicsAppState extends State<TitiSonicsApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightScheme, darkScheme) {
        final darkColorScheme = darkScheme?.harmonized() ??
            ColorScheme.fromSeed(
              seedColor: FlowyColors.brandSeed,
              brightness: Brightness.dark,
            );

        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: FlowyTheme.buildTheme(),
          darkTheme: FlowyTheme.buildTheme(colorScheme: darkColorScheme),
          themeMode: ThemeMode.dark,
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: FlowyColors.surface,
      body: Stack(
        children: [
          // ── Ambient background glow ─────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _AmbientGlowPainter(scheme.primary)),
          ),

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
        ],
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
  }
}

// ── Ambient glow background ──────────────────────────────────────────────────

class _AmbientGlowPainter extends CustomPainter {
  final Color color;
  _AmbientGlowPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topLeft,
        radius: 0.8,
        colors: [
          color.withOpacity(0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Second glow in opposite corner
    final paint2 = Paint()
      ..shader = RadialGradient(
        center: Alignment.bottomRight,
        radius: 0.7,
        colors: [
          FlowyColors.brandAccent.withOpacity(0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), paint2);
  }

  @override
  bool shouldRepaint(_AmbientGlowPainter old) => old.color != color;
}
