
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/player_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/entities.dart';

class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final queue = player.currentQueue;
    final currentIndex = player.currentIndex;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: FlowyTheme.glassDecoration(),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.playlist_play_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    'Cola de Reproducción',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${queue.length} canciones',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.only(bottom: 32),
                itemCount: queue.length,
                onReorder: (oldIdx, newIdx) {
                  player.moveQueueItem(oldIdx, newIdx);
                },
                itemBuilder: (context, index) {
                  final song = queue[index];
                  final isCurrent = index == currentIndex;

                  return _QueueTile(
                    key: ValueKey(song.id + index.toString()),
                    song: song,
                    index: index,
                    isCurrent: isCurrent,
                    onTap: () {
                      player.playAtIndex(index);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final SongEntity song;
  final int index;
  final bool isCurrent;
  final VoidCallback onTap;

  const _QueueTile({
    super.key,
    required this.song,
    required this.index,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              // Cover
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(song.bestThumbnail),
                    fit: BoxFit.cover,
                  ),
                ),
                child: isCurrent
                    ? Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: TextStyle(
                        color: isCurrent ? scheme.primary : Colors.white,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      song.artist,
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.drag_indicator_rounded, color: Colors.white10),
            ],
          ),
        ),
      ),
    ).animate(target: isCurrent ? 1 : 0).shimmer(
          duration: 2.seconds,
          color: Colors.white.withOpacity(0.05),
        );
  }
}
