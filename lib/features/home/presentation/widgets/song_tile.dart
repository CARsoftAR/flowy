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
import '../../../library/presentation/providers/library_provider.dart';
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
                    
                    // Progress bar for long tracks (like audiobooks)
                    Consumer<LibraryProvider>(
                      builder: (context, library, _) {
                        final progress = library.getBookmarkProgress(song.id, song.duration);
                        if (progress <= 0 || isCurrentSong) return const SizedBox.shrink();
                        
                        return Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
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
                              final success = await downloader.downloadSong(song, url, context: context);
                              if (context.mounted && success) {
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
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 20,
                          color: scheme.onSurface.withOpacity(0.3),
                        ),
                        offset: const Offset(0, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: Color.lerp(scheme.surface, Colors.black, 0.8),
                        onSelected: (value) async {
                          if (value == 'like') {
                            context.read<LibraryProvider>().toggleLike(song);
                          } else if (value == 'playlist') {
                            _showAddToPlaylistDialog(context, song);
                          }
                        },
                        itemBuilder: (context) {
                          final library = context.read<LibraryProvider>();
                          final isLiked = library.isLiked(song.id);
                          return [
                            PopupMenuItem(
                              value: 'like',
                              child: Row(
                                children: [
                                  Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                                      color: isLiked ? Colors.pink : scheme.primary, size: 20),
                                  const SizedBox(width: 12),
                                  Text(isLiked ? 'Quitar de favoritos' : 'Añadir a favoritos'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'playlist',
                              child: Row(
                                children: [
                                  Icon(Icons.playlist_add_rounded, color: scheme.primary, size: 20),
                                  const SizedBox(width: 12),
                                  const Text('Añadir a playlist'),
                                ],
                              ),
                            ),
                          ];
                        },
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

  void _showAddToPlaylistDialog(BuildContext context, SongEntity song) {
    final library = context.read<LibraryProvider>();
    final playlists = library.playlists;
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Color.lerp(scheme.surface, Colors.black, 0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Añadir a playlist',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const Divider(color: Colors.white10),
            if (playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.playlist_add_rounded, size: 48, color: Colors.white24),
                      const SizedBox(height: 12),
                      const Text('No tienes playlists creadas', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final p = playlists[index];
                    final hasSong = p.tracks.any((s) => s.id == song.id);

                    return ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white.withOpacity(0.05),
                        ),
                        child: p.thumbnailUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(imageUrl: p.thumbnailUrl!, fit: BoxFit.cover),
                              )
                            : const Icon(Icons.playlist_play_rounded),
                      ),
                      title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${p.tracks.length} canciones', style: const TextStyle(fontSize: 12)),
                      trailing: hasSong 
                          ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                          : null,
                      onTap: () {
                        if (!hasSong) {
                          library.addSongToPlaylist(p.id, song);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Añadido a ${p.title}'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
