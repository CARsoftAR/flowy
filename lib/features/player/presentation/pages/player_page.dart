import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/entities.dart';
import '../providers/player_provider.dart' as pp;
import 'package:flowy/features/library/presentation/providers/library_provider.dart';
import '../widgets/audio_wave_bar.dart';
import '../widgets/lyrics_view.dart';

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
  Color _dominantColor = FlowyColors.brandSeed;
  bool _showLyrics = false;

  @override
  void initState() {
    super.initState();
    _artworkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _extractColor();
  }

  @override
  void dispose() {
    _artworkController.dispose();
    super.dispose();
  }

  Future<void> _extractColor() async {
    final player = context.read<pp.PlayerProvider>();
    final song = player.currentSong;
    if (song == null) return;

    final color = await DynamicPaletteService()
        .getDominantColor(song.bestThumbnail);
    if (color != null && mounted) {
      setState(() => _dominantColor = color);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<pp.PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: _buildBody(context, player, song),
        );
      },
    );
  }

  Widget _buildBody(
      BuildContext context, pp.PlayerProvider player, SongEntity song) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Blurred full-screen album art background ───────────────────
        _buildBackground(song),

        // ── Dark overlay + gradient ────────────────────────────────────
        Container(
          decoration: FlowyTheme.playerGradient(_dominantColor),
        ),

        // ── Actual content ─────────────────────────────────────────────
        SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              const SizedBox(height: 8),

              // Artwork or Lyrics toggle
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppConstants.animationNormal,
                  child: _showLyrics
                      ? LyricsView(song: song, position: player.position)
                      : _buildArtworkSection(song),
                ),
              ),

              // Song info
              _buildSongInfo(context, player, song),
              const SizedBox(height: 8),

              // Audio wave bars
              AudioWaveBar(
                isPlaying: player.isPlaying,
                color: _dominantColor,
              ),
              const SizedBox(height: 8),

              // Progress bar
              _buildProgressBar(context, player),
              const SizedBox(height: 16),

              // Controls
              _buildControls(context, player),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            color: Colors.white,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'REPRODUCIENDO AHORA',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white60,
                        letterSpacing: 2,
                        fontSize: 10,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded),
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  // ── Artwork ───────────────────────────────────────────────────────────────

  Widget _buildArtworkSection(SongEntity song) {
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
                boxShadow: FlowyTheme.glowShadow(_dominantColor),
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
                        _dominantColor.withOpacity(0.3),
                        FlowyColors.surfaceContainer,
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.music_note, color: Colors.white30,
                        size: 64),
                  ),
                ),
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 3.seconds, color: Colors.white10),
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
          Consumer<LibraryProvider>(
            builder: (context, library, _) {
              final isLiked = library.isLiked(song.id);
              final scheme = Theme.of(context).colorScheme;
              return IconButton(
                onPressed: () => library.toggleLike(song),
                icon: Icon(
                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isLiked ? scheme.primary : Colors.white60,
                ),
                iconSize: 26,
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
              activeTrackColor: _dominantColor,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
              thumbColor: Colors.white,
              overlayColor: _dominantColor.withOpacity(0.2),
              trackHeight: 4,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: player.progress,
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
            onPressed: player.toggleShuffle,
            icon: Icon(
              Icons.shuffle_rounded,
              color:
                  player.isShuffle ? scheme.primary : Colors.white38,
              size: 22,
            ),
          ),

          // Previous
          IconButton(
            onPressed: player.skipToPrevious,
            icon: const Icon(Icons.skip_previous_rounded,
                color: Colors.white, size: 36),
          ),

          // Play/Pause
          _LargePlayButton(player: player, dominantColor: _dominantColor),

          // Next
          IconButton(
            onPressed: player.skipToNext,
            icon: const Icon(Icons.skip_next_rounded,
                color: Colors.white, size: 36),
          ),

          // Repeat
          IconButton(
            onPressed: player.cycleRepeatMode,
            icon: Icon(
              player.repeatMode == pp.RepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              color: player.repeatMode != pp.RepeatMode.off
                  ? scheme.primary
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
      onTap: player.togglePlayPause,
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
          .animate(target: player.isPlaying ? 1 : 0)
          .scale(begin: const Offset(1, 1), end: const Offset(0.92, 0.92))
          .then()
          .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1)),
    );
  }
}
