
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../domain/entities/entities.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../../core/theme/app_theme.dart';

class SmartPlaylistsRow extends StatelessWidget {
  const SmartPlaylistsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final playlists = [
      (
        'Tus más escuchadas',
        'Basado en tu historial reciente',
        Icons.auto_graph_rounded,
        [const Color(0xFF7C4DFF), const Color(0xFF00E5FF)],
        library.getMostPlayedSongs()
      ),
      (
        'Mix de energía',
        'Ritmos para activar tu día',
        Icons.bolt_rounded,
        [const Color(0xFFFF4081), const Color(0xFFFFD600)],
        library.getEnergyMix()
      ),
      (
        'Chill nocturno',
        'Música suave para relajar',
        Icons.nights_stay_rounded,
        [const Color(0xFF00BCD4), const Color(0xFF1DE9B6)],
        library.getChillMix()
      ),
    ];

    return SizedBox(
      height: 160,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: playlists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final item = playlists[index];
          final title = item.$1;
          final subtitle = item.$2;
          final icon = item.$3;
          final colors = item.$4;
          final tracks = item.$5;

          if (tracks.isEmpty && index > 0) return const SizedBox.shrink();

          return GestureDetector(
            onTap: () {
              if (tracks.isNotEmpty) {
                final player = context.read<PlayerProvider>();
                player.playSong(tracks.first, queue: tracks);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Reproduciendo $title'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Container(
              width: 260,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colors.first.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Icon(
                        icon,
                        size: 100,
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: Colors.white, size: 20),
                          ),
                          const Spacer(),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate(delay: Duration(milliseconds: index * 100)).fadeIn().slideX(begin: 0.1);
        },
      ),
    );
  }
}
