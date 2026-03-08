import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/skeleton_widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../domain/repositories/repositories.dart';
import '../../../../core/di/injection.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../widgets/song_tile.dart';
import '../widgets/section_header.dart';
import '../widgets/featured_banner.dart';
import '../widgets/smart_playlists_row.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HomePage — Discovery & Recommendations
// ─────────────────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MusicRepository _repo = sl<MusicRepository>();
  List<SongEntity>? _recommendations;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _repo.getRecommendations();
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = failure.message;
      }),
      (songs) => setState(() {
        _loading = false;
        _recommendations = songs;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadRecommendations,
        color: scheme.primary,
        backgroundColor: scheme.surfaceContainer,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── App Bar ─────────────────────────────────────────────────
            SliverAppBar(
              floating: true,
              backgroundColor: Colors.transparent,
              title: Row(
                children: [
                  Text(
                    'Flowy',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      foreground: Paint()
                        ..shader = LinearGradient(
                          colors: [scheme.primary, scheme.secondary],
                        ).createShader(
                            const Rect.fromLTWH(0, 0, 120, 40)),
                    ),
                  ),
                ],
              ),
              actions: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      onPressed: () => _showNotifications(context, theme, scheme),
                      icon: const Icon(Icons.notifications_outlined),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 2.seconds),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),

            // ── Greeting ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withOpacity(0.5),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: AppConstants.animationNormal),
                    Text(
                      '¿Qué quieres escuchar?',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    )
                        .animate()
                        .fadeIn(
                            delay: 100.ms,
                            duration: AppConstants.animationNormal)
                        .slideX(begin: -0.03),
                  ],
                ),
              ),
            ),

            // ── Featured Banner ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: _loading || _recommendations == null || _recommendations!.isEmpty
                  ? const SizedBox.shrink()
                  : FeaturedBanner(songs: _recommendations!.take(5).toList()),
            ),

            // ── Smart Playlists header ─────────────────────────────────
            const SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Mixes para ti',
                subtitle: 'Basado en lo que escuchas',
              ),
            ),

            const SliverToBoxAdapter(
              child: SmartPlaylistsRow(),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Trending Songs header ────────────────────────────────────
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Tendencias actuales',
                onSeeAll: () {},
              ),
            ),

            // ── Song List ────────────────────────────────────────────────
            _loading
                ? const SliverToBoxAdapter(
                    child: SongListSkeleton(count: 10),
                  )
                : _error != null
                    ? SliverToBoxAdapter(
                        child: _ErrorState(
                          message: _error!,
                          onRetry: _loadRecommendations,
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final song = _recommendations![index];
                            return SongTile(
                              song: song,
                              index: index,
                              onTap: () {
                                final player = context.read<PlayerProvider>();
                                final library = context.read<LibraryProvider>();
                                player.playSong(song, queue: _recommendations);
                                library.addToHistory(song);
                              },
                            );
                          },
                          childCount: _recommendations?.length ?? 0,
                        ),
                      ),

            const SliverToBoxAdapter(
              child: SizedBox(
                  height: AppConstants.miniPlayerHeight +
                      AppConstants.navBarHeight +
                      16),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '¡Buenos días! ☀️';
    if (hour < 18) return '¡Buenas tardes! 🎵';
    return '¡Buenas noches! 🌙';
  }

  void _showNotifications(BuildContext context, ThemeData theme, ColorScheme scheme) {
    final library = context.read<LibraryProvider>();
    final recentSongs = library.recentlyPlayed;
    
    // Determine a dynamic genre/tag from recent history
    String recommendedGenre = "música que te gusta";
    if (recentSongs.isNotEmpty) {
      final lastSong = recentSongs.first;
      recommendedGenre = "${lastSong.artist} y similares";
    }

    final totalPlays = library.getMostPlayedSongs().length;
    final topSong = library.getMostPlayedSongs().isNotEmpty ? library.getMostPlayedSongs().first.title : "Flowy";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Color.lerp(scheme.surface, Colors.black, 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  children: [
                    Text(
                      'Tus Novedades',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildNotifItem(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Tu Mix de Energía',
                      desc: 'Hemos actualizado tu mezcla basado en $recommendedGenre.',
                      time: 'RECIÉN ACTUALIZADO',
                      color: Colors.amber,
                    ),
                    _buildNotifItem(
                      icon: Icons.rocket_launch_rounded,
                      title: 'Audio Engine v2.0',
                      desc: 'La optimización de bajos y agudos está activa para tus cascos actuales.',
                      time: 'MOTOR ACTIVO',
                      color: scheme.primary,
                    ),
                    _buildNotifItem(
                      icon: Icons.favorite_rounded,
                      title: 'Fan de la Semana',
                      desc: 'Has escuchado $totalPlays canciones únicas. Tu favorita es "$topSong".',
                      time: 'RESUMEN SEMANAL',
                      color: Colors.pinkAccent,
                      showStats: true,
                      stats: [
                        _StatItem(label: 'Total Canciones', value: '$totalPlays'),
                        _StatItem(label: 'Top Artista', value: recentSongs.isNotEmpty ? recentSongs.first.artist : '---'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotifItem({
    required IconData icon,
    required String title,
    required String desc,
    required String time,
    required Color color,
    bool showStats = false,
    List<_StatItem>? stats,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900, 
                        fontSize: 17,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        time,
                        style: TextStyle(
                          color: color, 
                          fontSize: 9, 
                          fontWeight: FontWeight.w900, 
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      desc,
                      style: const TextStyle(
                        color: Colors.white54, 
                        fontSize: 14, 
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showStats && stats != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Divider(color: Colors.white.withOpacity(0.08), height: 1),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stats.isNotEmpty ? _buildStatColumn(stats[0]) : const SizedBox(),
                const SizedBox(width: 12),
                stats.length > 1 ? _buildStatColumn(stats[1], flex: 2) : const SizedBox(),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStatColumn(_StatItem s, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            s.value, 
            style: const TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w900, 
              color: Colors.white,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            s.label.toUpperCase(), 
            style: const TextStyle(
              fontSize: 8, 
              color: Colors.white38, 
              letterSpacing: 1.2, 
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  _StatItem({required this.label, required this.value});
}

// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 56, color: Colors.white30),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              shape: const StadiumBorder(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
