import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/realtime_visualizer.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/ambient_background.dart';
import '../../../../core/widgets/flowy_marquee.dart';
import '../../../../domain/entities/entities.dart';
import 'package:flowy/features/player/presentation/providers/player_provider.dart'
    as pp;
import 'package:flowy/features/library/presentation/providers/download_provider.dart';
import 'package:flowy/features/library/presentation/providers/library_provider.dart';
import '../widgets/audio_wave_bar.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/playback_speed_sheet.dart';
import '../widgets/volume_sheet.dart';
import '../widgets/chapter_sheet.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with TickerProviderStateMixin {
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
            child: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 8),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 700),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: _showLyrics
                          ? LyricsView(
                              key: const ValueKey('lyrics'),
                              song: song,
                              position: player.position,
                              onTap: () => setState(() => _showLyrics = false),
                            )
                          : _buildVideoSection(song, player),
                    ),
                  ),
                  _buildSongInfo(context, player, song),
                  const SizedBox(height: 8),
                  AudioWaveBar(
                    isPlaying: player.isPlaying,
                    color: player.dominantColor,
                  ),
                  const SizedBox(height: 8),
                  _buildControls(context, player),
                  const SizedBox(height: 24),
                  _buildProgressBar(context, player),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

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
                builder: (context) => const SleepTimerSheet(),
              );
            },
            icon: const Icon(Icons.nights_stay_rounded),
            color: Colors.white,
          ),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => const VolumeSheet(),
              );
            },
            icon: const Icon(Icons.volume_up_rounded),
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkSection(SongEntity song, Color dominantColor) {
    final player = context.read<pp.PlayerProvider>();
    return Padding(
      key: const ValueKey('artwork'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.8,
            child: Transform.scale(
              scale: 1.4,
              child: RealtimeVisualizer(
                isPlaying: player.isPlaying,
                color: dominantColor,
              ),
            ),
          ),
          AspectRatio(
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
                  child: AnimatedScale(
                    scale: player.isPlaying ? 1.0 : 0.95,
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                    child: CachedNetworkImage(
                      imageUrl: song.bestThumbnail,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.black),
                      errorWidget: (_, __, ___) =>
                          Container(color: Colors.black),
                    ),
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                    begin: const Offset(1.0, 1.0),
                    end: const Offset(1.02, 1.02),
                    duration: 1.seconds,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasVideoUrl(pp.PlayerProvider player, SongEntity song) {
    final url = player.handler.getCachedVideoUrl(song.id);
    return url != null && url.isNotEmpty;
  }

  Widget _buildVideoSection(SongEntity song, pp.PlayerProvider player) {
    final streamUrl = player.handler.getCachedVideoUrl(song.id);
    final hasVideo = streamUrl != null && streamUrl.isNotEmpty;
    debugPrint(
        '🎥 VideoSection: hasVideo=$hasVideo, url=${streamUrl?.substring(0, 30)}');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Capa base (fondo): carátula - solo visible si NO hay video
            if (!hasVideo)
              CachedNetworkImage(
                imageUrl: song.bestThumbnail,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.black),
                errorWidget: (_, __, ___) => Container(color: Colors.black),
              ),
            // Capa video (superior): intenta reproducir si hay URL
            if (hasVideo)
              VideoPlayerWidget(
                key: ValueKey('${streamUrl}_${song.id}'),
                songId: song.id,
                streamUrl: streamUrl,
                coverUrl: song.bestThumbnail,
                isPlaying: player.isPlaying,
                position: player.position,
              )
            else
              Container(color: Colors.black54),
          ],
        ),
      ),
    );
  }

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
                FlowyMarquee(
                  text: song.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
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
                ).animate().fadeIn(
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
                  IconButton(
                    onPressed: () async {
                      if (isDownloaded) {
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
                              value: (progress == 0.0) ? null : progress,
                              strokeWidth: 2,
                              color: player.dominantColor,
                            ),
                          )
                        : Icon(
                            isDownloaded
                                ? Icons.download_done_rounded
                                : Icons.download_rounded,
                            color: isDownloaded
                                ? player.dominantColor
                                : Colors.white60,
                          ),
                    iconSize: 26,
                  ),
                  IconButton(
                    onPressed: () => library.toggleLike(song),
                    icon: Icon(
                      isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
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

  Widget _buildProgressBar(BuildContext context, pp.PlayerProvider player) {
    final accentColor = player.dominantColor;
    final brightAccent = HSLColor.fromColor(accentColor)
        .withLightness(0.6)
        .withSaturation(1.0)
        .toColor();
    const neonCyan = Color(0xFF00F2FF);
    const barHeight = 28.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // ── Timer Labels (Clearly Separated) ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(player.position),
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  _formatDuration(player.duration),
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: Colors.white60,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Custom Thick Progress Bar (no Flutter Slider clipping) ──────────
          GestureDetector(
            onTapDown: (details) {
              HapticEngine.selection();
              final box = context.findRenderObject() as RenderBox;
              // Account for padding (24 each side)
              final localX = details.localPosition.dx;
              final barWidth =
                  box.size.width - 48; // subtract horizontal padding
              final ratio = ((localX) / box.size.width).clamp(0.0, 1.0);
              final newPos = Duration(
                milliseconds: (ratio * player.duration.inMilliseconds).round(),
              );
              player.seekTo(newPos);
            },
            onHorizontalDragUpdate: (details) {
              final box = context.findRenderObject() as RenderBox;
              final ratio =
                  (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
              final newPos = Duration(
                milliseconds: (ratio * player.duration.inMilliseconds).round(),
              );
              player.seekTo(newPos);
            },
            child: SizedBox(
              height: barHeight + 16, // extra space for glow
              child: CustomPaint(
                size: Size(double.infinity, barHeight + 16),
                painter: _ThickProgressBarPainter(
                  progress: player.progress,
                  barHeight: barHeight,
                  activeGradient: LinearGradient(
                    colors: [
                      brightAccent.withOpacity(0.7),
                      brightAccent,
                      neonCyan,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  inactiveColor: Colors.white.withOpacity(0.12),
                  glowColor: brightAccent,
                  thumbColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, pp.PlayerProvider player) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 40,
            spreadRadius: -12,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _GlassControlButton(
            icon: Icons.shuffle_rounded,
            isActive: player.isShuffle,
            activeColor: player.dominantColor,
            onTap: () {
              HapticEngine.light();
              player.toggleShuffle();
            },
          ),
          _GlassControlButton(
            icon: Icons.skip_previous_rounded,
            iconSize: 34,
            onTap: () {
              HapticEngine.medium();
              player.skipToPrevious();
            },
          ),
          _EtherealPlayButton(
              player: player, dominantColor: player.dominantColor),
          _GlassControlButton(
            icon: Icons.skip_next_rounded,
            iconSize: 34,
            onTap: () {
              HapticEngine.medium();
              player.skipToNext();
            },
          ),
          _GlassControlButton(
            icon: player.repeatMode == pp.FlowyRepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            isActive: player.repeatMode != pp.FlowyRepeatMode.off,
            activeColor: player.dominantColor,
            onTap: () {
              HapticEngine.light();
              player.cycleRepeatMode();
            },
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

class _EtherealPlayButton extends StatelessWidget {
  final pp.PlayerProvider player;
  final Color dominantColor;

  const _EtherealPlayButton(
      {required this.player, required this.dominantColor});

  @override
  Widget build(BuildContext context) {
    final vibrantColor = HSLColor.fromColor(dominantColor)
        .withLightness(0.6)
        .withSaturation(1.0)
        .toColor();
    final deepColor =
        HSLColor.fromColor(dominantColor).withLightness(0.15).toColor();

    return GestureDetector(
      onTap: () {
        HapticEngine.medium();
        player.togglePlayPause();
      },
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: vibrantColor.withOpacity(0.5).withValues(alpha: 0.5),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Internal Glow Layer
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [vibrantColor, deepColor],
                ),
              ),
            ),
            // Frosted Glass Layer
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.white.withOpacity(0.4), width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.25),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
              ),
            ),
            // Icon
            player.isLoading
                ? const CircularProgressIndicator(
                    strokeWidth: 3, color: Colors.white)
                : Icon(
                    player.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
          ],
        ),
      )
          .animate(target: player.isPlaying ? 1 : 0)
          .scale(
              begin: const Offset(1, 1),
              end: const Offset(0.92, 0.92),
              duration: 200.ms)
          .shimmer(duration: 3.seconds, color: Colors.white.withOpacity(0.3)),
    );
  }
}

class _GlassControlButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback onTap;

  const _GlassControlButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 28,
    this.isActive = false,
    this.activeColor,
  });

  @override
  State<_GlassControlButton> createState() => _GlassControlButtonState();
}

class _GlassControlButtonState extends State<_GlassControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.activeColor ?? Colors.white;
    final color = widget.isActive
        ? accent
        : (_isHovered ? Colors.white : Colors.white.withOpacity(0.6));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.white.withOpacity(0.08)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: _isHovered
                  ? Colors.white.withOpacity(0.15)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Icon(
            widget.icon,
            color: color,
            size: widget.iconSize,
            shadows: widget.isActive
                ? [Shadow(color: accent.withOpacity(0.6), blurRadius: 10)]
                : null,
          ),
        ),
      ),
    );
  }
}

// ── Hyper-Modern Painters ───────────────────────────────────────────────────

class _LiquidBeamTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  final Gradient gradient;
  final Color glowColor;

  _LiquidBeamTrackShape({required this.gradient, required this.glowColor});

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final activePaint = Paint()..shader = gradient.createShader(trackRect);
    final inactivePaint = Paint()..color = sliderTheme.inactiveTrackColor!;

    // Liquid Glow Aura
    final auraPaint = Paint()
      ..color = glowColor.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final activeRect = Rect.fromLTRB(
        trackRect.left, trackRect.top, thumbCenter.dx, trackRect.bottom);
    final inactiveRect = Rect.fromLTRB(
        thumbCenter.dx, trackRect.top, trackRect.right, trackRect.bottom);

    // Draw Inactive
    context.canvas.drawRRect(
        RRect.fromRectAndRadius(inactiveRect, const Radius.circular(24)),
        inactivePaint);

    // Draw Aura/Glow for Active
    context.canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, const Radius.circular(24)),
        auraPaint);

    // Draw Liquid Beam (Active)
    context.canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, const Radius.circular(24)),
        activePaint);

    // Inner Sharp Light Streak
    final streakPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    final streakRect = Rect.fromLTRB(trackRect.left + 5, trackRect.top + 2,
        thumbCenter.dx - 5, trackRect.top + 5);
    context.canvas.drawRRect(
        RRect.fromRectAndRadius(streakRect, const Radius.circular(10)),
        streakPaint);
  }
}

class _CrystalGlowThumbShape extends RoundSliderThumbShape {
  final Color glowColor;
  const _CrystalGlowThumbShape(
      {required this.glowColor, double enabledThumbRadius = 14.0})
      : super(enabledThumbRadius: enabledThumbRadius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    // Diamond Glow
    final glowPaint = Paint()
      ..color = glowColor.withOpacity(0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, enabledThumbRadius * 1.6, glowPaint);

    // Main Crystal Body
    final thumbPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, glowColor.withOpacity(0.1)],
      ).createShader(
          Rect.fromCircle(center: center, radius: enabledThumbRadius));
    canvas.drawCircle(center, enabledThumbRadius, thumbPaint);

    // High-Gloss Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, enabledThumbRadius, borderPaint);

    // Inner Core
    final corePaint = Paint()..color = glowColor;
    canvas.drawCircle(center, 5, corePaint);
  }
}

// ─── Deprecated Classes Removed in favor of Ethereal Styles ───

// ── Thick Custom Progress Bar Painter ─────────────────────────────────────────

class _ThickProgressBarPainter extends CustomPainter {
  final double progress;
  final double barHeight;
  final Gradient activeGradient;
  final Color inactiveColor;
  final Color glowColor;
  final Color thumbColor;

  _ThickProgressBarPainter({
    required this.progress,
    required this.barHeight,
    required this.activeGradient,
    required this.inactiveColor,
    required this.glowColor,
    required this.thumbColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barTop = (size.height - barHeight) / 2;
    final barRect = Rect.fromLTWH(0, barTop, size.width, barHeight);
    final radius = Radius.circular(barHeight / 2);

    // ── Inactive Track (full width, clearly visible) ──────────────────────
    final inactivePaint = Paint()..color = inactiveColor;
    canvas.drawRRect(RRect.fromRectAndRadius(barRect, radius), inactivePaint);

    // ── Active Track (gradient fill) ──────────────────────────────────────
    if (progress > 0.001) {
      final activeWidth = size.width * progress;
      final activeRect = Rect.fromLTWH(0, barTop, activeWidth, barHeight);

      // Glow behind active
      final glowPaint = Paint()
        ..color = glowColor.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawRRect(RRect.fromRectAndRadius(activeRect, radius), glowPaint);

      // Active gradient fill
      final activePaint = Paint()
        ..shader = activeGradient.createShader(activeRect);
      canvas.drawRRect(
          RRect.fromRectAndRadius(activeRect, radius), activePaint);

      // Glass streak on top
      final streakRect = Rect.fromLTWH(4, barTop + 3, activeWidth - 8, 4);
      if (streakRect.width > 0) {
        final streakPaint = Paint()..color = Colors.white.withOpacity(0.25);
        canvas.drawRRect(
          RRect.fromRectAndRadius(streakRect, const Radius.circular(2)),
          streakPaint,
        );
      }

      // ── Thumb Circle ──────────────────────────────────────────────────
      final thumbX = activeWidth.clamp(0.0, size.width);
      final thumbY = barTop + barHeight / 2;
      final thumbRadius = barHeight * 0.55;

      // Thumb glow
      final thumbGlowPaint = Paint()
        ..color = glowColor.withOpacity(0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(
          Offset(thumbX, thumbY), thumbRadius * 1.3, thumbGlowPaint);

      // Thumb body
      final thumbPaint = Paint()..color = thumbColor;
      canvas.drawCircle(Offset(thumbX, thumbY), thumbRadius, thumbPaint);

      // Thumb inner core
      final corePaint = Paint()..color = glowColor;
      canvas.drawCircle(Offset(thumbX, thumbY), 4, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ThickProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowColor != glowColor;
  }
}
