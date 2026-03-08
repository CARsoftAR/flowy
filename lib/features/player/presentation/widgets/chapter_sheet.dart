import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/player_provider.dart';

class ChapterSheet extends StatelessWidget {
  const ChapterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final chapters = player.chapters;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.bookmarks_rounded, color: player.dominantColor),
                const SizedBox(width: 12),
                Text(
                  'Capítulos',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${chapters.length} encontrados',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
                ),
              ],
            ),
          ),

          if (chapters.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No se detectaron capítulos en este audio.',
                style: TextStyle(color: Colors.white38),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: chapters.length,
                itemBuilder: (context, index) {
                  final chapter = chapters[index];
                  final isCurrent = _isCurrentChapter(chapter, index, chapters, player.position);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    leading: Container(
                      width: 40,
                      alignment: Alignment.center,
                      child: Text(
                        _formatDuration(chapter.startTime),
                        style: TextStyle(
                          color: isCurrent ? player.dominantColor : Colors.white38,
                          fontSize: 12,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    title: Text(
                      chapter.title,
                      style: TextStyle(
                        color: isCurrent ? Colors.white : Colors.white70,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isCurrent 
                      ? Icon(Icons.play_arrow_rounded, color: player.dominantColor)
                      : null,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      player.seekTo(chapter.startTime);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  bool _isCurrentChapter(chapter, int index, List chapters, Duration position) {
    if (position < chapter.startTime) return false;
    if (index == chapters.length - 1) return true;
    return position < chapters[index + 1].startTime;
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
