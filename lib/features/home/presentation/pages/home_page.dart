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
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_outlined),
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
