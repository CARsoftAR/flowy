import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/entities.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../library/presentation/providers/download_provider.dart';
import '../../../../domain/repositories/repositories.dart';
import '../../../../core/di/injection.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SongTile — Animated list item for a track
// ─────────────────────────────────────────────────────────────────────────────

class SongTile extends StatelessWidget {
  final SongEntity song;
  final int index;
  final VoidCallback onTap;
  final bool showIndex;

  const SongTile({
    super.key,
    required this.song,
    required this.index,
    required this.onTap,
    this.showIndex = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final player = context.watch<PlayerProvider>();
    final isCurrentSong = player.currentSong?.id == song.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: scheme.primary.withOpacity(0.1),
        child: AnimatedContainer(
          duration: AppConstants.animationFast,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: isCurrentSong
              ? BoxDecoration(
                  color: scheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Row(
            children: [
              // ── Artwork / Index ────────────────────────────────────────
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'song_artwork_${song.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: song.thumbnailUrl ?? '',
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(Icons.music_note,
                                color: scheme.primary.withOpacity(0.5),
                                size: 20),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(Icons.music_note,
                                color: scheme.primary.withOpacity(0.5),
                                size: 20),
                          ),
                        ),
                      ),
                    ),
                    // Playing indicator overlay
                    if (isCurrentSong)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.equalizer_rounded,
                            color: scheme.primary, size: 24),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // ── Info ───────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      song.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isCurrentSong
                            ? scheme.primary
                            : scheme.onSurface,
                        fontWeight: isCurrentSong
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      song.artist,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withOpacity(0.55),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // ── Download + More ────────────────────────────────────────
              Consumer<DownloadProvider>(
                builder: (context, downloader, _) {
                  final isDownloaded = downloader.isDownloaded(song.id);
                  final isDownloading = downloader.isDownloading(song.id);
                  final isFetching = downloader.isFetching(song.id);
                  final progress = downloader.getProgress(song.id);

                  Widget trailingIcon;

                  if (isDownloaded) {
                    trailingIcon = Icon(Icons.check_circle_rounded, color: scheme.primary, size: 22);
                  } else if (isDownloading || isFetching) {
                    trailingIcon = GestureDetector(
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        downloader.cancelDownload(song.id);
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 2.5,
                              color: scheme.primary,
                            ),
                          ),
                          Icon(Icons.close_rounded, size: 14, color: scheme.primary),
                        ],
                      ),
                    );
                  } else {
                    trailingIcon = IconButton(
                      icon: const Icon(Icons.download_for_offline_outlined, size: 24),
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        downloader.setFetching(song.id, true);
                        try {
                          final repo = sl<MusicRepository>();
                          final result = await repo.getStreamUrl(song.id);
                          result.fold(
                            (f) {
                              downloader.setFetching(song.id, false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${f.message}')),
                              );
                            },
                            (url) async {
                              downloader.setFetching(song.id, false);
                              final success = await downloader.downloadSong(song, url);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success ? '¡Descargado!' : 'Error al descargar'),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          );
                        } catch (e) {
                          downloader.setFetching(song.id, false);
                        }
                      },
                      color: scheme.onSurface.withOpacity(0.4),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    );
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      trailingIcon,
                      const SizedBox(width: 8),
                      Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: scheme.onSurface.withOpacity(0.3),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 50))
        .fadeIn(duration: AppConstants.animationNormal)
        .slideX(begin: 0.04, end: 0);
  }
}
