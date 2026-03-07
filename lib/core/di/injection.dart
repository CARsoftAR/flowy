import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../data/datasources/audio_handler.dart';
import '../../data/datasources/lyrics_datasource.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../domain/repositories/repositories.dart';
import '../../features/player/presentation/providers/player_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Service Locator — manual dependency injection using get_it
// ─────────────────────────────────────────────────────────────────────────────

final sl = GetIt.instance;

Future<void> configureDependencies({
  required FlowyAudioHandler audioHandler,
}) async {
  // ── Infrastructure ────────────────────────────────────────────────────────
  sl.registerLazySingleton<Logger>(
    () => Logger(
      printer: PrettyPrinter(methodCount: 2, errorMethodCount: 8),
      level: Level.debug,
    ),
  );

  sl.registerLazySingleton<YoutubeExplode>(() => YoutubeExplode());

  sl.registerLazySingleton<LyricsDataSource>(() => LyricsDataSource());

  // ── Repositories ──────────────────────────────────────────────────────────
  sl.registerLazySingleton<MusicRepository>(
    () => MusicRepositoryImpl(
      youtubeExplode: sl<YoutubeExplode>(),
      lyricsSource: sl<LyricsDataSource>(),
      logger: sl<Logger>(),
    ),
  );

  // ── Audio Handler (pre-initialized, passed in) ────────────────────────────
  sl.registerSingleton<FlowyAudioHandler>(audioHandler);

  // ── Provider ──────────────────────────────────────────────────────────────
  sl.registerLazySingleton<PlayerProvider>(
    () => PlayerProvider(handler: sl<FlowyAudioHandler>()),
  );
}
