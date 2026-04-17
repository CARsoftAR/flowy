import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/stats_provider.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../../core/widgets/flowy_marquee.dart';
import '../../../../core/theme/app_theme.dart';

class _NeonColors {
  static const Color purple = Color(0xFFA020F0);
  static const Color blue = Color(0xFF00BFFF);
  static const Color pink = Color(0xFFFF1493);
  static const Color orange = Color(0xFFFF8C00);
  static const Color green = Color(0xFF39FF14);
  static const Color cyan = Color(0xFF00FFFF);

  static List<Color> get palette => [blue, pink, orange, green, purple, cyan];
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = context.watch<StatsProvider>();
    final library = context.watch<LibraryProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // ── Fixed Header ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Text(
              'Tu Estilo',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 32,
                foreground: Paint()
                  ..shader = const LinearGradient(
                    colors: [Colors.white, Colors.white60],
                  ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
              ),
            ),
          ),

          // ── Scrollable Content ─────────────────────────────────────────
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPremiumSummaryCard(context, stats),
                        const SizedBox(height: 40),
                        _buildCyberGenreSection(context, stats),
                        const SizedBox(height: 40),
                        _buildTopSongsSection(context, library),
                        const SizedBox(height: 120),
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

  Widget _buildPremiumSummaryCard(BuildContext context, StatsProvider stats) {
    return _HoverStatsCard(
      child: Stack(
        children: [
          // Glow effect behind the card
          Positioned(
            top: 20,
            left: 40,
            right: 40,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: _NeonColors.blue.withOpacity(0.4),
                    blurRadius: 60,
                    spreadRadius: -10,
                  ),
                  BoxShadow(
                    color: _NeonColors.pink.withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: -20,
                    offset: const Offset(50, 0),
                  ),
                ],
              ),
            ),
          ),
          
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.12),
                      Colors.white.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _NeonColors.blue.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.flash_on_rounded, color: _NeonColors.blue, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'TEMPO MUSICAL',
                          style: GoogleFonts.outfit(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${stats.totalMinutes}',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 56,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'min',
                          style: GoogleFonts.outfit(
                            color: _NeonColors.cyan,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildBetterMiniStat('Vibra', '${stats.playCounts.length}', _NeonColors.pink),
                        _buildBetterMiniStat('Géneros', '${stats.genreCounts.length}', _NeonColors.orange),
                        _buildBetterMiniStat('Flow', '98%', _NeonColors.green),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
  }

  Widget _buildBetterMiniStat(String label, String value, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 9,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accentColor.withOpacity(0.2)),
          ),
          child: Text(
            value,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCyberGenreSection(BuildContext context, StatsProvider stats) {
    final topGenres = stats.getTopGenres();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ADN Musical',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: Colors.white,
              ),
            ),
            Icon(Icons.query_stats_rounded, color: Colors.white30, size: 24),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 6,
                      centerSpaceRadius: 35,
                      startDegreeOffset: 270,
                      sections: _buildBetterPieSections(context, topGenres),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: topGenres.map((g) => _buildBetterGenreIndicator(context, g)).toList(),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms).shimmer(color: Colors.white10),
      ],
    );
  }

  List<PieChartSectionData> _buildBetterPieSections(BuildContext context, List<MapEntry<String, int>> genres) {
    final colors = _NeonColors.palette;

    return List.generate(genres.length, (i) {
      final percentage = (genres[i].value / genres.fold(0, (sum, g) => sum + g.value)) * 100;
      final color = colors[i % colors.length];
      
      return PieChartSectionData(
        color: color,
        value: genres[i].value.toDouble(),
        title: '${percentage.toInt()}%',
        radius: 40,
        badgeWidget: _buildPieBadge(color),
        badgePositionPercentageOffset: 1.3,
        titleStyle: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          shadows: [const Shadow(color: Colors.black54, blurRadius: 4)],
        ),
      );
    });
  }

  Widget _buildPieBadge(Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.8), blurRadius: 8, spreadRadius: 2),
        ],
      ),
    );
  }

  Widget _buildBetterGenreIndicator(BuildContext context, MapEntry<String, int> genre) {
    final colors = _NeonColors.palette;
    final index = context.read<StatsProvider>().getTopGenres().indexOf(genre);
    final color = colors[index % colors.length];
    final total = context.read<StatsProvider>().genreCounts.values.fold(0, (sum, val) => sum + val);
    final percentage = (genre.value / total * 100).toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                genre.key,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700, 
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const Spacer(),
              Text(
                '$percentage%',
                style: GoogleFonts.outfit(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: genre.value / total,
              backgroundColor: Colors.white.withOpacity(0.03),
              valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.5)),
              minHeight: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSongsSection(BuildContext context, LibraryProvider library) {
    final topSongs = library.getMostPlayedSongs(limit: 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'En Bucle',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        if (topSongs.isEmpty)
          const Text('Aún no has escuchado suficientes temas.', style: TextStyle(color: Colors.white30))
        else
          ...topSongs.asMap().entries.map((entry) {
            final index = entry.key;
            final song = entry.value;
            final playCount = library.getPlayCount(song.id);
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _NeonColors.palette[index % 5].withOpacity(0.4), width: 2),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: CachedNetworkImage(
                          imageUrl: song.bestThumbnail,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FlowyMarquee(
                          text: song.title,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          song.artist,
                          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildPulsePlayCount(context, playCount, _NeonColors.palette[index % 5]),
                ],
              ),
            ).animate(delay: (400 + (index * 100)).ms).fadeIn().slideX(begin: 0.1, end: 0);
          }).toList(),
      ],
    );
  }

  Widget _buildPulsePlayCount(BuildContext context, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: color,
            ),
          ),
          const Text(
            'SPINS',
            style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white30),
          ),
        ],
      ),
    );
  }
}

class _HoverStatsCard extends StatefulWidget {
  final Widget child;
  const _HoverStatsCard({required this.child});

  @override
  State<_HoverStatsCard> createState() => _HoverStatsCardState();
}

class _HoverStatsCardState extends State<_HoverStatsCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: widget.child,
      ),
    );
  }
}
