import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/premium_transitions.dart';
import '../../../../domain/entities/entities.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../player/presentation/pages/player_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MiniPlayer — persistent bottom player (Spotify style)
// Supports swipe-up to expand into full PlayerPage
// ─────────────────────────────────────────────────────────────────────────────

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  double _opacity = 1.0;

  // Rastreamos el ID de la canción actual para resetear la animación
  // cuando el usuario elige una canción nueva después de un dismiss
  String? _lastSongId;

  /// Resetea el estado de animación si la canción cambió
  void _resetIfNewSong(String? songId) {
    if (songId != null && songId != _lastSongId) {
      _lastSongId = songId;
      if (_dragOffset != 0.0 || _opacity != 1.0) {
        // Usar addPostFrameCallback para no llamar setState durante build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _dragOffset = 0.0;
              _opacity = 1.0;
            });
          }
        });
      }
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
      _opacity = (1.0 - (_dragOffset.abs() / 200)).clamp(0.0, 1.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details, PlayerProvider player) {
    final velocity = details.primaryVelocity ?? 0;
    const threshold = 120.0;

    if (_dragOffset.abs() > threshold || velocity.abs() > 400) {
      _dismiss(player);
    } else {
      // No llegó al umbral → volver al centro
      setState(() {
        _dragOffset = 0.0;
        _opacity = 1.0;
      });
    }
  }

  Future<void> _dismiss(PlayerProvider player) async {
    final direction = _dragOffset < 0 ? -1.0 : 1.0;
    setState(() {
      _dragOffset = direction * 400;
      _opacity = 0.0;
    });
    await Future.delayed(const Duration(milliseconds: 220));
    if (mounted) {
      // Después de detener, player.stop() pone status=idle y currentSong=null
      // → el Consumer devolverá SizedBox.shrink() y el mini player desaparece
      await player.stop();
      // Resetear el offset para que cuando aparezca la próxima canción
      // el widget ya esté en posición correcta
      if (mounted) {
        setState(() {
          _dragOffset = 0.0;
          _opacity = 1.0;
          _lastSongId = null; // forzar re-check en la próxima canción
        });
      }
    }
  }

  void _openFullPlayer(BuildContext context) {
    Navigator.of(context).push(
      PremiumTransitions.slideUp(const PlayerPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;

        // Si no hay canción o el player está idle → no renderizar nada
        // (esto también evita que el widget invisible bloquee los taps)
        if (song == null || player.status == PlayerStatus.idle) {
          return const SizedBox.shrink();
        }

        // Resetear animación si es una canción nueva
        _resetIfNewSong(song.id);

        // Mostrar banner de error si hay un problema
        if (player.hasError) {
          return _ErrorBanner(
            message: player.errorMessage ?? 'Error de reproducción',
            onDismiss: player.clearError,
            onRetry: () => player.playSong(song, queue: player.queue),
          );
        }

        return AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 120),
          child: Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: GestureDetector(
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: (d) => _onHorizontalDragEnd(d, player),
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < -200) {
                  _openFullPlayer(context);
                }
              },
              onTap: () {
                HapticEngine.medium();
                _openFullPlayer(context);
              },
              child: _MiniPlayerContent(song: song, player: player),
            ),
          ),
        );
      },
    );
  }
}

class _MiniPlayerContent extends StatelessWidget {
  final SongEntity song;
  final PlayerProvider player;

  const _MiniPlayerContent({required this.song, required this.player});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      height: AppConstants.miniPlayerHeight,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: FlowyTheme.glowShadow(player.dominantColor, intensity: 0.3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Blurred background ─────────────────────────────────────────
          if (song.bestThumbnail.isNotEmpty)
            CachedNetworkImage(
              imageUrl: song.bestThumbnail,
              fit: BoxFit.cover,
              color: Colors.black54,
              colorBlendMode: BlendMode.darken,
            ),

          // ── Glassmorphism overlay ──────────────────────────────────────
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: FlowyTheme.glassDecoration(
                borderRadius: 18,
                opacity: 0.25,
                tintColor: player.dominantColor,
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Artwork
                Hero(
                  tag: 'song_artwork_${song.id}',
                  child: ClipRoundedRect(
                    radius: 10,
                    child: CachedNetworkImage(
                      imageUrl: song.bestThumbnail,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 48,
                        height: 48,
                        color: scheme.surfaceContainerHighest,
                        child: Icon(Icons.music_note,
                            color: scheme.primary, size: 20),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Title + Artist
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ControlButton(
                      icon: Icons.skip_previous_rounded,
                      onTap: () {
                        HapticEngine.light();
                        player.skipToPrevious();
                      },
                    ),
                    const SizedBox(width: 4),
                    _PlayPauseButton(player: player),
                    const SizedBox(width: 4),
                    _ControlButton(
                      icon: Icons.skip_next_rounded,
                      onTap: () {
                        HapticEngine.light();
                        player.skipToNext();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Progress bar at bottom ─────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: player.progress,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(player.dominantColor),
              minHeight: 2,
            ),
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: 1, end: 0, duration: AppConstants.animationNormal)
        .fadeIn(duration: AppConstants.animationNormal);
  }
}

class _PlayPauseButton extends StatelessWidget {
  final PlayerProvider player;
  const _PlayPauseButton({required this.player});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticEngine.medium();
        player.togglePlayPause();
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: player.dominantColor,
          shape: BoxShape.circle,
        ),
        child: player.isLoading
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              )
            : Icon(
                player.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: ThemeData.estimateBrightnessForColor(player.dominantColor) == Brightness.light
                    ? Colors.black87
                    : Colors.white,
                size: 22,
              ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white70, size: 24),
    );
  }
}

// Helper widget for rounded rectangles
class ClipRoundedRect extends StatelessWidget {
  final double radius;
  final Widget child;
  const ClipRoundedRect({super.key, required this.radius, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ErrorBanner — Se muestra cuando el player falla al cargar una pista
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  final VoidCallback onRetry;

  const _ErrorBanner({
    required this.message,
    required this.onDismiss,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFB00020).withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB00020).withOpacity(0.4),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Botón reintentar
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Reintentar',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          // Botón cerrar
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),
        ],
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 300)).slideY(begin: 0.3, end: 0);
  }
}
