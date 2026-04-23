import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/constants/app_constants.dart';
import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/audio_handler.dart';
import 'data/repositories/music_repository_impl.dart';
import 'services/flowy_engine.dart';
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
import 'core/layout/desktop_shell.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:media_kit/media_kit.dart';

import 'core/network/flowy_http_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  HttpOverrides.global = IPv4HttpOverrides();
  
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    if (Platform.isWindows) {
      MediaKit.ensureInitialized();
      JustAudioMediaKit.ensureInitialized(windows: true);
      debugPrint('Windows Native Media Engines Initialized (Impeller workaround applied)');
    }
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  
  _runAppWithSafety();
}

void _runAppWithSafety() {
  runZonedGuarded(() async {
    await _init();
  }, (error, stack) {
    debugPrint('Critical Init Error: $error\n$stack');
    runApp(_ErrorApp(
      message: error.toString(),
      onRetry: () => _runAppWithSafety(),
    ));
  });
}

Future<void> _init() async {
  // Motor de streaming: se inicializa en BACKGROUND para no bloquear el arranque.
  // La app carga inmediatamente con la URL de fallback, y el motor se actualiza solo.
  FlowyEngine.initialize(); // intencionalmente sin await

  if (Platform.isAndroid || Platform.isIOS) {
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
  }

  final musicRepo = MusicRepositoryImpl();
  
  SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    throw Exception('Error al acceder al almacenamiento local.');
  }

  FlowyAudioHandler audioHandler;
  try {
    audioHandler = await AudioService.init<FlowyAudioHandler>(
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
  } catch (e) {
    throw Exception('Error al iniciar el motor de audio.');
  }

  await configureDependencies(
    audioHandler: audioHandler,
  );

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

class FlowyApp extends StatelessWidget {
  const FlowyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Flowy',
          theme: FlowyTheme.buildTheme(colorScheme: darkDynamic),
          home: Builder(
            builder: (context) => SplashPage(
              onFinish: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const FlowyShell()),
              ),
            ),
          ),
        );
      },
    );
  }
}

class FlowyShell extends StatefulWidget {
  const FlowyShell({super.key});

  @override
  State<FlowyShell> createState() => _FlowyShellState();
}

class _FlowyShellState extends State<FlowyShell> {
  int _selectedIndex = 0;

  List<Widget> get _pages => [
    const HomePage(),
    const SearchPage(),
    const LibraryPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = Platform.isWindows || constraints.maxWidth > 900;

        if (isDesktop) {
          return DesktopShell(
            pages: _pages,
            selectedIndex: _selectedIndex,
            onIndexChanged: (i) => setState(() => _selectedIndex = i),
          );
        }

        return Consumer<PlayerProvider>(
          builder: (context, player, child) {
            return Scaffold(
              backgroundColor: FlowyColors.surface,
              body: AmbientBackground(
                imageUrl: player.currentSong?.bestThumbnail,
                overlayOpacity: 0.7,
                child: Stack(
                  children: [
                    IndexedStack(
                      index: _selectedIndex,
                      children: _pages,
                    ),
                    Positioned(
                      bottom: AppConstants.navBarHeight + 4,
                      left: 0,
                      right: 0,
                      child: const MiniPlayer(),
                    ),
                    if (player.isLoading) const AudioLoadingOverlay(),
                  ],
                ),
              ),
              bottomNavigationBar: SafeArea(
                child: NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Inicio',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.search_outlined),
                      selectedIcon: Icon(Icons.search_rounded),
                      label: 'Buscar',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.library_music_outlined),
                      selectedIcon: Icon(Icons.library_music_rounded),
                      label: 'Biblioteca',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ErrorApp extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorApp({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onRetry, child: const Text('REINTENTAR')),
            ],
          ),
        ),
      ),
    );
  }
}
