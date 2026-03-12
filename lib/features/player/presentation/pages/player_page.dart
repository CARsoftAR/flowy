import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/video_player_widget.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/ambient_background.dart';
import '../../../../domain/entities/entities.dart';
import 'package:flowy/features/player/presentation/providers/player_provider.dart' as pp;
import 'package:flowy/features/library/presentation/providers/download_provider.dart';
import 'package:flowy/features/library/presentation/providers/library_provider.dart';
import '../widgets/audio_wave_bar.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/playback_speed_sheet.dart';
import '../widgets/chapter_sheet.dart';
import '../providers/audio_effects_provider.dart';
import '../providers/sleep_timer_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PlayerPage — Full-screen immersive player
// ─────────────────────────────────────────────────────────────────────────────

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with TickerProviderStateMixin {
  late final AnimationController _artworkController;
  bool _showLyrics = false;

  @override
  void initState() {
    super.initState();
    _artworkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _artworkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<pp.PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AmbientBackground(
            imageUrl: song.bestThumbnail,
            dominantColor: player.dominantColor,
            overlayOpacity: 0.2,
            child: _buildBody(context, player, song),
          ),
        );
      },
    );
  }

  Widget _buildBody(
      BuildContext context, pp.PlayerProvider player, SongEntity song) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Content is now wrapped by AmbientBackground in build()

        // ── Actual content ─────────────────────────────────────────────
        SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              const SizedBox(height: 8),

              // Artwork, Lyrics or Video toggle
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppConstants.animationNormal,
                  child: _showLyrics
                      ? LyricsView(song: song, position: player.position)
                      : (song.isVideo 
                          ? _buildVideoSection(song, player)
                          : _buildArtworkSection(song, player.dominantColor)),
                ),
              ),

              // Song info
              _buildSongInfo(context, player, song),
              const SizedBox(height: 8),

              // Audio wave bars
              if (!song.isVideo) ...[
                AudioWaveBar(
                  isPlaying: player.isPlaying,
                  color: player.dominantColor,
                ),
                const SizedBox(height: 8),
              ],

              // Progress bar
              if (!song.isVideo) ...[
                _buildProgressBar(context, player),
                const SizedBox(height: 16),
              ],

              // Controls
              _buildControls(context, player),
              const SizedBox(height: 24),
            ],
          ),
        ),

        // ── Resume Prompt Layer ──────────────────────────────────────
        if (player.resumeRequest != null)
          _buildResumePrompt(context, player),
      ],
    );
  }

  Widget _buildResumePrompt(BuildContext context, pp.PlayerProvider player) {
    final req = player.resumeRequest!;
    final seconds = req['seconds'] as int? ?? 0;
    final timeStr = _formatDuration(Duration(seconds: seconds));

    return Positioned(
      bottom: 120,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: player.dominantColor.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: player.dominantColor.withOpacity(0.15),
              blurRadius: 30,
              spreadRadius: 5,
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: player.dominantColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_rounded, color: player.dominantColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'Retomar donde lo dejaste',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: player.dominantColor.withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Continuar desde $timeStr',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => player.clearResumeRequest(),
              child: Text('Ignorar', style: TextStyle(color: Colors.white.withOpacity(0.5))),
            ),
            ElevatedButton(
              onPressed: () {
                player.seekTo(Duration(seconds: seconds));
                player.clearResumeRequest();
                HapticFeedback.mediumImpact();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: player.dominantColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                elevation: 0,
              ),
              child: const Text('SI', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack),
    );
  }

  // ── Background ────────────────────────────────────────────────────────────

  Widget _buildBackground(SongEntity song) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
      child: CachedNetworkImage(
        imageUrl: song.bestThumbnail,
        fit: BoxFit.cover,
        color: Colors.black.withOpacity(0.3),
        colorBlendMode: BlendMode.darken,
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    final player = context.watch<pp.PlayerProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            color: Colors.white,
          ),
          const Spacer(),
          if (player.chapters.isNotEmpty)
            IconButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const ChapterSheet(),
                );
              },
              icon: const Icon(Icons.bookmarks_rounded),
              color: player.dominantColor,
            ),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => const PlaybackSpeedSheet(),
              );
            },
            icon: const Icon(Icons.speed_rounded),
            color: Colors.white,
          ),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => const QueueSheet(),
              );
            },
            icon: const Icon(Icons.playlist_play_rounded),
            color: Colors.white,
          ),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => const EqualizerSheet(),
              );
            },
            icon: const Icon(Icons.tune_rounded),
            color: Colors.white,
          ),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => const SleepTimerSheet(),
              );
            },
            icon: const Icon(Icons.nights_stay_rounded),
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkSection(SongEntity song, Color dominantColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          onTap: () => setState(() => _showLyrics = !_showLyrics),
          child: Hero(
            tag: 'song_artwork_${song.id}',
            child: AnimatedContainer(
              duration: AppConstants.animationNormal,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: FlowyTheme.glowShadow(dominantColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: song.bestThumbnail,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  decoration: BoxDecoration(
                    color: FlowyColors.surfaceContainer,
                    gradient: LinearGradient(
                      colors: [
                        dominantColor.withOpacity(0.3),
                        FlowyColors.surfaceContainer,
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.music_note, color: Colors.white30, size: 64),
                  ),
                ),
              ),
            ),
          ).animate(onPlay: (c) => c.repeat())
           .shimmer(duration: 3.seconds, color: Colors.white10),
        ),
      ),
    );
  }

  Widget _buildVideoSection(SongEntity song, pp.PlayerProvider player) {
    final streamUrl = player.handler.getCachedUrl(song.id);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: FlowyTheme.glowShadow(player.dominantColor, intensity: 0.3),
          ),
          clipBehavior: Clip.antiAlias,
          child: streamUrl != null 
            ? VideoPlayerWidget(
                streamUrl: streamUrl,
                isPlaying: player.isPlaying,
                position: player.position,
              )
            : Container(
                color: Colors.black,
                child: const Center(child: CircularProgressIndicator()),
              ),
        ),
      ),
    );
  }

  // ── Song Info ─────────────────────────────────────────────────────────────

  Widget _buildSongInfo(
      BuildContext context, pp.PlayerProvider player, SongEntity song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
                    .animate()
                    .fadeIn(duration: AppConstants.animationNormal)
                    .slideX(begin: -0.05),
                const SizedBox(height: 4),
                Text(
                  song.artist,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white60,
                      ),
                )
                    .animate()
                    .fadeIn(
                        delay: 100.ms, duration: AppConstants.animationNormal),
              ],
            ),
          ),
          Consumer2<LibraryProvider, DownloadProvider>(
            builder: (context, library, download, _) {
              final isLiked = library.isLiked(song.id);
              final isDownloaded = download.isDownloaded(song.id);
              final progress = download.getProgress(song.id);
              final isDownloading = download.isDownloading(song.id);

              return Row(
                children: [
                  // Download button
                  IconButton(
                    onPressed: () async {
                      if (isDownloaded) {
                         // Mostrar confirmación de borrado opcional? Por ahora no.
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Canción descargada')),
                         );
                      } else if (isDownloading) {
                        download.cancelDownload(song.id);
                      } else {
                        HapticFeedback.lightImpact();
                        download.downloadSong(song, context: context);
                      }
                    },
                    icon: isDownloading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 2,
                              color: player.dominantColor,
                            ),
                          )
                        : Icon(
                            isDownloaded
                                ? Icons.download_done_rounded
                                : Icons.download_rounded,
                            color: isDownloaded ? player.dominantColor : Colors.white60,
                          ),
                    iconSize: 26,
                  ),

                  // Like button
                  IconButton(
                    onPressed: () => library.toggleLike(song),
                    icon: Icon(
                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isLiked ? player.dominantColor : Colors.white60,
                    ),
                    iconSize: 26,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Progress Bar ──────────────────────────────────────────────────────────

  Widget _buildProgressBar(BuildContext context, pp.PlayerProvider player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Glow progress slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: player.dominantColor,
              inactiveTrackColor: Colors.white.withOpacity(0.12),
              thumbColor: Colors.white,
              overlayColor: player.dominantColor.withOpacity(0.2),
              trackHeight: 4,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: player.progress,
              onChangeStart: (_) => HapticFeedback.selectionClick(),
              onChanged: (v) {
                final duration = player.duration;
                final newPos = Duration(
                  milliseconds: (v * duration.inMilliseconds).round(),
                );
                player.seekTo(newPos);
              },
            ),
          ),

          // Time labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(player.position),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Colors.white60),
                ),
                Text(
                  _formatDuration(player.duration),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  Widget _buildControls(BuildContext context, pp.PlayerProvider player) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Shuffle
          IconButton(
            onPressed: () {
              HapticEngine.light();
              player.toggleShuffle();
            },
            icon: Icon(
              Icons.shuffle_rounded,
              color:
                  player.isShuffle ? player.dominantColor : Colors.white38,
              size: 22,
            ),
          ),

          // Previous
          IconButton(
            onPressed: () {
              HapticEngine.medium();
              player.skipToPrevious();
            },
            icon: const Icon(Icons.skip_previous_rounded,
                color: Colors.white, size: 36),
          ),

          // Play/Pause
          _LargePlayButton(player: player, dominantColor: player.dominantColor),

          // Next
          IconButton(
            onPressed: () {
              HapticEngine.medium();
              player.skipToNext();
            },
            icon: const Icon(Icons.skip_next_rounded,
                color: Colors.white, size: 36),
          ),

          // Repeat
          IconButton(
            onPressed: () {
              HapticEngine.light();
              player.cycleRepeatMode();
            },
            icon: Icon(
              player.repeatMode == pp.RepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              color: player.repeatMode != pp.RepeatMode.off
                  ? player.dominantColor
                  : Colors.white38,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LargePlayButton extends StatelessWidget {
  final pp.PlayerProvider player;
  final Color dominantColor;

  const _LargePlayButton(
      {required this.player, required this.dominantColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticEngine.medium();
        player.togglePlayPause();
      },
      child: AnimatedContainer(
        duration: AppConstants.animationFast,
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: dominantColor,
          shape: BoxShape.circle,
          boxShadow: FlowyTheme.glowShadow(dominantColor),
        ),
        child: player.isLoading
            ? const Center(
                child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              ))
            : Icon(
                player.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 38,
              ),
      )
          .animate(
            target: player.isPlaying ? 1 : 0,
            onPlay: (c) => c.repeat(),
          )
          .scale(begin: const Offset(1, 1), end: const Offset(0.92, 0.92))
          .then()
          .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1))
          .shimmer(
            duration: 2.seconds,
            color: Colors.white.withOpacity(0.2),
          ),
    );
  }
}
