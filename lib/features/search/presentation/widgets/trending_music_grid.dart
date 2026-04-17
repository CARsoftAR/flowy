
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../core/theme/app_theme.dart';

class TrendingMusicGrid extends StatelessWidget {
  final List<SongEntity> songs;
  final Function(SongEntity) onTap;

  const TrendingMusicGrid({
    super.key,
    required this.songs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Text(
                'Tendencias Globales',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.trending_up_rounded, color: FlowyColors.brandAccent, size: 20),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: songs.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final song = songs[index];
              return _TrendingCard(
                song: song,
                index: index,
                onTap: () => onTap(song),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final SongEntity song;
  final int index;
  final VoidCallback onTap;

  const _TrendingCard({
    required this.song,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Hero(
                  tag: 'trending_${song.id}',
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(song.bestThumbnail),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FlowyColors.brandAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: FlowyColors.brandAccent.withOpacity(0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: (index * 100).ms).fadeIn(duration: 500.ms).slideX(begin: 0.1, curve: Curves.easeOut);
  }
}
