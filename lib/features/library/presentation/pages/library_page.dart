import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:flowy/domain/entities/entities.dart';
import 'package:flowy/features/player/presentation/providers/player_provider.dart';
import 'package:flowy/features/library/presentation/providers/library_provider.dart';
import 'package:flowy/features/library/presentation/providers/download_provider.dart';
import 'package:flowy/features/home/presentation/widgets/song_tile.dart';
import 'package:flowy/features/home/presentation/widgets/section_header.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LibraryPage — User's saved songs, playlists and history
// ─────────────────────────────────────────────────────────────────────────────

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  // 0: Playlists, 1: Liked Songs, 2: Recently Played
  int _viewIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                title: Text(
                  _viewIndex == 0 ? 'Tu Biblioteca' : (_viewIndex == 1 ? 'Me gusta' : (_viewIndex == 2 ? 'Recientes' : 'Descargas')),
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                floating: true,
                backgroundColor: Colors.transparent,
                actions: [
                  if (_viewIndex == 0)
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'Nueva playlist',
                    ),
                  if (_viewIndex != 0)
                    IconButton(
                      onPressed: () => setState(() => _viewIndex = 0),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),

              // ── Quick Actions ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _QuickActionChip(
                        icon: Icons.favorite_rounded,
                        label: 'Me gusta',
                        color: const Color(0xFFFF4081),
                        isSelected: _viewIndex == 1,
                        onTap: () => setState(() => _viewIndex = _viewIndex == 1 ? 0 : 1),
                      ),
                      const SizedBox(width: 10),
                      _QuickActionChip(
                        icon: Icons.history_rounded,
                        label: 'Recientes',
                        color: const Color(0xFF7C4DFF),
                        isSelected: _viewIndex == 2,
                        onTap: () => setState(() => _viewIndex = _viewIndex == 2 ? 0 : 2),
                      ),
                      const SizedBox(width: 10),
                      _QuickActionChip(
                        icon: Icons.download_done_rounded,
                        label: 'Descargas',
                        color: scheme.primary,
                        isSelected: _viewIndex == 3,
                        onTap: () => setState(() => _viewIndex = _viewIndex == 3 ? 0 : 3),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Playlists header ─────────────────────────────────────────────
              if (_viewIndex == 0)
                const SliverToBoxAdapter(
                  child: SectionHeader(title: 'Tus Playlists'),
                ),

              // ── Empty playlists state ────────────────────────────────────────
              if (_viewIndex == 0)
                _buildEmptyPlaylists(theme, scheme),

              // ── Liked Songs / Recently Played / Downloads List ───────────────────────────
              if (_viewIndex != 0)
                _buildLibraryList(
                  _viewIndex == 1 
                    ? library.likedSongs 
                    : (_viewIndex == 2 
                        ? library.recentlyPlayed 
                        : context.watch<DownloadProvider>().downloadedSongs)
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyPlaylists(ThemeData theme, ColorScheme scheme) {
    return SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withOpacity(0.12),
                  boxShadow: FlowyTheme.glowShadow(scheme.primary, intensity: 0.3),
                ),
                child: Icon(
                  Icons.library_music_rounded,
                  size: 48,
                  color: scheme.primary,
                ),
              ).animate(onPlay: (c) => c.repeat()).scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.05, 1.05),
                    duration: 1500.ms,
                  ).then().scale(
                    begin: const Offset(1.05, 1.05),
                    end: const Offset(1, 1),
                    duration: 1500.ms,
                  ),
              const SizedBox(height: 20),
              Text(
                'Tu biblioteca está vacía',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Busca música y guarda tus archivos favoritos aquí',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.45),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crear playlist'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryList(List<SongEntity> songs) {
    if (songs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              Icon(Icons.queue_music_rounded, size: 48, color: Colors.white12),
              const SizedBox(height: 16),
              Text(
                'No hay canciones aquí todavía',
                style: TextStyle(color: Colors.white30),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final song = songs[index];
          return SongTile(
            song: song,
            index: index,
            onTap: () {
              final player = context.read<PlayerProvider>();
              final library = context.read<LibraryProvider>();
              player.playSong(song, queue: songs);
              library.addToHistory(song);
            },
          );
        },
        childCount: songs.length,
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSelected
                  ? [color, color.withOpacity(0.8)]
                  : [color.withOpacity(0.3), color.withOpacity(0.15)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? Colors.white24 : color.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? Colors.white : color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
