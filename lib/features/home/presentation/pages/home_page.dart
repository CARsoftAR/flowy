import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/skeleton_shimmer.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../domain/repositories/repositories.dart';
import '../../../../core/di/injection.dart';
import '../../../../services/flowy_engine.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../library/presentation/providers/library_provider.dart';

import '../widgets/song_tile.dart';
import '../widgets/section_header.dart';
import '../widgets/mood_filters_row.dart';
import '../widgets/radio_stations_row.dart';
import '../widgets/add_custom_radio_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/widgets/flowy_song_card.dart';

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
  bool _isRefreshingConfig = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
    
    // Escuchar errores del reproductor para mostrarlos en pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = context.read<PlayerProvider>();
      player.addListener(() {
        if (player.hasError && player.errorMessage != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Error: ${player.errorMessage}')),
                ],
              ),
              backgroundColor: Colors.redAccent.withOpacity(0.9),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'REINTENTAR',
                textColor: Colors.white,
                onPressed: () async {
                  // Refrescar el motor antes de reintentar
                  await FlowyEngine.refresh();
                  if (player.currentSong != null) {
                    player.playSong(player.currentSong!);
                  }
                },
              ),
            ),
          );
        }
      });
    });
  }

  Future<void> _refreshConnectionMotor() async {
    setState(() => _isRefreshingConfig = true);
    debugPrint('DEBUG: Solicitando actualización de Motor dinámico...');
    await FlowyEngine.refresh();
    debugPrint('DEBUG: Motor Activo - ${FlowyEngine.currentApiUrl}');
    if (mounted) {
      setState(() => _isRefreshingConfig = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Motor Activo: ${FlowyEngine.currentApiUrl}'),
          backgroundColor: Colors.green.withOpacity(0.8),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
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

  void _showAddRadioDialog(BuildContext context) async {
    final radio = await showAddCustomRadioDialog(context);
    if (radio != null && mounted) {
      final player = context.read<PlayerProvider>();
      final song = SongEntity(
        id: 'radio_${radio.id}',
        title: radio.name,
        artist: radio.genre,
        streamUrl: radio.streamUrl,
        isDirectStream: true,
        isLive: true,
      );
      player.playSong(song);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final player = context.watch<PlayerProvider>();
    final dominantColor = player.dominantColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Ambient Glow Background
          Positioned(
            top: -100,
            right: -100,
            child: AnimatedContainer(
              duration: const Duration(seconds: 2),
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    dominantColor.withOpacity(0.15),
                    dominantColor.withOpacity(0.0),
                  ],
                ),
              ),
            ).animate(onPlay: (c) => c.repeat()).moveX(begin: 0, end: 50, duration: 10.seconds, curve: Curves.easeInOut).moveY(begin: 0, end: 30, duration: 8.seconds, curve: Curves.easeInOut),
          ),

          Positioned.fill(
            child: Column(
              children: [
              // ── Fixed Header ──────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(isDesktop ? 32 : 28, isDesktop ? 48 : 32, 28, 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getGreeting(),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w900,
                              fontSize: isDesktop ? 40 : 28,
                              letterSpacing: -1,
                              color: Colors.white,
                            ),
                          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, curve: Curves.easeOutBack),
                        ),
                        
                        // ── Connection Motor Status Icon ───────────────────────
                        Tooltip(
                          message: 'Motor dinámico activo: ${FlowyEngine.currentApiUrl}',
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.greenAccent.withOpacity(0.3),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.podcasts_rounded, color: Colors.greenAccent, size: 20),
                          ).animate(onPlay: (c) => c.repeat(reverse: true))
                           .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 1.5.seconds, curve: Curves.easeInOut),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // ── Refresh Motor Button ──────────────────────────────
                        _isRefreshingConfig 
                          ? const SizedBox(
                              width: 24, 
                              height: 24, 
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)
                            )
                          : IconButton(
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white60, size: 22),
                              onPressed: _refreshConnectionMotor,
                              tooltip: 'Refrescar Motor de Conexión',
                            ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    const MoodFiltersRow(),
                    const SizedBox(height: 32),
                    const RadioStationsRow(),
                  ],
                ),
              ),

              // ── Scrollable Content ─────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadRecommendations,
                  color: scheme.primary,
                  backgroundColor: Colors.black,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      // ── Recent Grid (Desktop Highlight) ──────────────────────────────
                      if (isDesktop && _recommendations != null && _recommendations!.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 20,
                              crossAxisSpacing: 20,
                              childAspectRatio: 3.8,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final song = _recommendations![index % _recommendations!.length];
                                return MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => _playSong(context, song),
                                    child: _DesktopRecentCard(song: song),
                                  ),
                                );
                              },
                              childCount: 6,
                            ),
                          ),
                        ),

                      const SliverToBoxAdapter(child: SizedBox(height: 48)),

                      // ── Section Header ──────────────────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(left: isDesktop ? 16 : 0),
                          child: SectionHeader(
                            title: isDesktop ? 'Tus favoritos exclusivos' : 'Tendencias',
                            onSeeAll: () {},
                          ),
                        ),
                      ),

                      // ── Song Grid / List ────────────────────────────────────────
                      _loading
                          ? _buildLoadingSliver(isDesktop)
                          : _error != null
                              ? SliverToBoxAdapter(
                                  child: _ErrorState(
                                    message: _error!,
                                    onRetry: _loadRecommendations,
                                  ),
                                )
                              : isDesktop
                                  ? SliverPadding(
                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                                      sliver: SliverGrid(
                                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 150,
                                          mainAxisSpacing: 32,
                                          crossAxisSpacing: 32,
                                          childAspectRatio: 0.72,
                                        ),
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) {
                                            final song = _recommendations![index];
                                            return FlowySongCard(
                                              song: song,
                                              onTap: () => _playSong(context, song),
                                            );
                                          },
                                          childCount: _recommendations?.length ?? 0,
                                        ),
                                      ),
                                    )
                                  : SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final song = _recommendations![index];
                                          return SongTile(
                                            song: song,
                                            index: index,
                                            onTap: () => _playSong(context, song),
                                          );
                                        },
                                        childCount: _recommendations?.length ?? 0,
                                      ),
                                    ),

                      const SliverToBoxAdapter(
                        child: SizedBox(height: 150),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  void _playSong(BuildContext context, SongEntity song) {
    debugPrint('🔥 Intentando reproducir canción: ${song.title}');
    HapticEngine.light();
    final player = context.read<PlayerProvider>();
    final library = context.read<LibraryProvider>();
    player.playSong(song, queue: _recommendations);
    library.addToHistory(song);
  }

  Widget _buildLoadingSliver(bool isDesktop) {
    if (isDesktop) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 150,
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            childAspectRatio: 0.8,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => SkeletonShimmer.rect(width: 180, height: 240, borderRadius: 12),
            childCount: 8,
          ),
        ),
      );
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: List.generate(8, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                SkeletonShimmer.rect(width: 56, height: 56, borderRadius: 12),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonShimmer.rect(width: 180, height: 16),
                      const SizedBox(height: 8),
                      SkeletonShimmer.rect(width: 100, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          )),
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
                        _StatItem(label: 'Total', value: '$totalPlays'),
                        _StatItem(
                          label: recentSongs.isNotEmpty ? 'POR ${recentSongs.first.artist}' : 'ARTISTA', 
                          value: topSong
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
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
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: Colors.white.withOpacity(0.08), height: 1),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatColumn(stats[0]),
                const SizedBox(width: 20),
                _buildStatColumn(stats[1], flex: 3, alignment: CrossAxisAlignment.start),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStatColumn(_StatItem s, {int flex = 1, CrossAxisAlignment alignment = CrossAxisAlignment.center}) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            s.value, 
            style: const TextStyle(
              fontSize: 15, 
              fontWeight: FontWeight.w900, 
              color: Colors.white,
              height: 1.2,
              letterSpacing: -0.4,
            ),
            textAlign: alignment == CrossAxisAlignment.center ? TextAlign.center : TextAlign.left,
            maxLines: 3,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 4),
          Text(
            s.label.toUpperCase(), 
            style: TextStyle(
              fontSize: 8, 
              color: Colors.white.withOpacity(0.4), 
              letterSpacing: 1.2, 
              fontWeight: FontWeight.w800,
            ),
            textAlign: alignment == CrossAxisAlignment.center ? TextAlign.center : TextAlign.left,
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
      padding: const EdgeInsets.fromLTRB(28, 24, 12, 8),
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
class _DesktopRecentCard extends StatefulWidget {
  final SongEntity song;
  const _DesktopRecentCard({required this.song});

  @override
  State<_DesktopRecentCard> createState() => _DesktopRecentCardState();
}

class _DesktopRecentCardState extends State<_DesktopRecentCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            color: _isHovered ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? Colors.white.withOpacity(0.2) : Colors.white10,
              width: 0.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              CachedNetworkImage(
                imageUrl: widget.song.bestThumbnail,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.song.title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800, 
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              _PlayButtonOverlay(size: 36, iconSize: 24, isHovered: _isHovered),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideX(begin: 0.1, curve: Curves.easeOutCubic);
  }
}

class _DesktopSongCard extends StatelessWidget {
  final SongEntity song;
  final VoidCallback onTap;

  const _DesktopSongCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: FlowyTheme.glassDecoration(
          borderRadius: 24,
          opacity: 0.05,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: song.bestThumbnail,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: _PlayButtonOverlay(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              song.title,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700, 
                fontSize: 16,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              song.artist,
              style: const TextStyle(
                color: Colors.white54, 
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack);
  }
}

class _PlayButtonOverlay extends StatelessWidget {
  final double size;
  final double iconSize;
  final bool isHovered;

  const _PlayButtonOverlay({
    this.size = 48, 
    this.iconSize = 32,
    this.isHovered = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isHovered ? FlowyColors.brandAccent : FlowyColors.brandSeed,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isHovered ? 0.6 : 0.4),
            blurRadius: isHovered ? 15 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.play_arrow_rounded, 
        color: Colors.black, 
        size: iconSize
      ),
    );
  }
}

