import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/player/presentation/providers/player_provider.dart';
import '../../core/constants/app_constants.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ambient_background.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/entities.dart';
import '../../features/library/presentation/providers/library_provider.dart';
import '../../features/player/presentation/widgets/mini_player.dart';
import '../../features/player/presentation/pages/player_page.dart';
import '../../features/player/presentation/widgets/queue_sheet.dart';
import '../../core/theme/premium_transitions.dart';
import '../../services/flowy_engine.dart';

class DesktopShell extends StatefulWidget {
  final List<Widget> pages;
  final int selectedIndex;
  final Function(int) onIndexChanged;

  const DesktopShell({
    super.key,
    required this.pages,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  String? _lastSongId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = context.read<PlayerProvider>();
      _lastSongId = player.currentSong?.id;

      player.addListener(() {
        if (player.hasError && player.errorMessage != null) {
          _showError(context, player.errorMessage!, player);
        }

        final currentSongId = player.currentSong?.id;
        if (currentSongId != null && currentSongId != _lastSongId) {
          _lastSongId = currentSongId;
        }
      });
    });
  }

  void _openFullPlayer(BuildContext context) {
    Navigator.of(context).push(
      PremiumTransitions.slideUp(const PlayerPage()),
    );
  }

  void _showError(BuildContext context, String message, PlayerProvider player) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                player.clearError();
              },
              child: const Text('CERRAR',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showProviderSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _ProviderSelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Scaffold(
      backgroundColor: FlowyColors.surface,
      body: AmbientBackground(
        imageUrl: player.currentSong?.bestThumbnail,
        child: Stack(
          children: [
            // ── Mica Effect Layer (Simulated) ───────────────────────────────
            Positioned.fill(
              child: Container(
                color: FlowyColors.surface.withOpacity(0.4),
              ),
            ),

            // ── Main Layout ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(
                  20.0), // increased padding for breathe room
              child: Row(
                children: [
                  // ── Sidebar (Narrow, Fluent style) ────────────────────────
                  _FloatingSidebar(
                    selectedIndex: widget.selectedIndex,
                    onIndexChanged: widget.onIndexChanged,
                  ),
                  const SizedBox(width: 20),

                  // ── Main Content Area ─────────────────────────────────────
                  Expanded(
                    child: Column(
                      children: [
                        _PremiumTopBar(),
                        const SizedBox(height: 20),
                        Expanded(
                          child: Container(
                            decoration: FlowyTheme.glassDecoration(
                              borderRadius: 20,
                              opacity: 0.03, // Extra subtle for content area
                              showShadow: false,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: IndexedStack(
                              index: widget.selectedIndex,
                              children: widget.pages,
                            ),
                          ),
                        ),
                        // Space for floating player
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Floating Player Dock ─────────────────────────────────────────
            Positioned(
              bottom: 24,
              left: 104,
              right: 24,
              child: _FloatingPlayerDock(player: player),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;

  const _FloatingSidebar({
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68, // slightly narrower
      decoration: FlowyTheme.glassDecoration(
        borderRadius: 24,
        opacity: 0.06,
        showShadow: true,
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          _SidebarIcon(
            icon: Icons.home_rounded,
            isSelected: selectedIndex == 0,
            onTap: () => onIndexChanged(0),
          ),
          const SizedBox(height: 24),
          _SidebarIcon(
            icon: Icons.search_rounded,
            isSelected: selectedIndex == 1,
            onTap: () => onIndexChanged(1),
          ),
          const SizedBox(height: 24),
          _SidebarIcon(
            icon: Icons.library_music_rounded,
            isSelected: selectedIndex == 2,
            onTap: () => onIndexChanged(2),
          ),
          const Spacer(),
          if (AppConstants.isPremium)
            _SidebarIcon(
              icon: Icons.auto_graph_rounded,
              isSelected: selectedIndex == 3,
              onTap: () => onIndexChanged(3),
              color: const Color(0xFFFFD700),
            ),
        ],
      ),
    );
  }
}

class _SidebarIcon extends StatefulWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _SidebarIcon({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  State<_SidebarIcon> createState() => _SidebarIconState();
}

class _SidebarIconState extends State<_SidebarIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? FlowyColors.brandAccent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? activeColor.withOpacity(0.18)
                  : (_isHovered
                      ? Colors.white.withOpacity(0.08)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(16),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.25),
                        blurRadius: 20,
                        spreadRadius: -2,
                      )
                    ]
                  : null,
            ),
            child: Icon(
              widget.icon,
              color: (widget.isSelected || _isHovered)
                  ? activeColor
                  : Colors.white54,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumTopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 8),
        Text(
          'Flowy',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        _GlassButton(
          icon: Icons.notifications_none_rounded,
          onTap: () {},
        ),
        const SizedBox(width: 12),
        _GlassButton(
          icon: Icons.settings_outlined,
          onTap: () {},
        ),
        const SizedBox(width: 16),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
              image: const DecorationImage(
                image: NetworkImage('https://i.pravatar.cc/150?u=flowy'),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                )
              ]),
        ),
      ],
    );
  }
}

class _GlassButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassButton({required this.icon, required this.onTap});

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.white.withOpacity(0.12)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isHovered
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
              ),
            ),
            child: Icon(widget.icon,
                color: _isHovered ? FlowyColors.brandAccent : Colors.white70,
                size: 22),
          ),
        ),
      ),
    );
  }
}

class _FloatingPlayerDock extends StatelessWidget {
  final PlayerProvider player;
  const _FloatingPlayerDock({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: FlowyTheme.glassDecoration(
        borderRadius: 24,
        opacity: 0.12,
        borderWidth: 1.0,
        tintColor:
            player.currentSong != null ? player.dominantColor : Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _DesktopPlayerBar(player: player),
        ),
      ),
    );
  }
}

class _DesktopPlayerBar extends StatelessWidget {
  final PlayerProvider player;

  const _DesktopPlayerBar({required this.player});

  @override
  Widget build(BuildContext context) {
    final song = player.currentSong;

    final accentColor = player.dominantColor;

    return SizedBox(
      height: 116,
      child: Row(
        children: [
          // ── Left: Song Info ───────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: song == null
                ? const SizedBox.shrink()
                : Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: -4,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 15,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              PremiumTransitions.slideUp(const PlayerPage()),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: CachedNetworkImage(
                              imageUrl: song.bestThumbnail,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              song.artist,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      _SmallGlassButton(
                        icon: context.watch<LibraryProvider>().isLiked(song.id)
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        iconColor:
                            context.watch<LibraryProvider>().isLiked(song.id)
                                ? Colors.pinkAccent
                                : Colors.white70,
                        onTap: () =>
                            context.read<LibraryProvider>().toggleLike(song),
                      ),
                      const SizedBox(width: 8),
                      _SmallGlassButton(
                        icon: Icons.fullscreen_rounded,
                        iconColor: Colors.white70,
                        onTap: () {
                          Navigator.of(context).push(
                            PremiumTransitions.slideUp(const PlayerPage()),
                          );
                        },
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 40),
          // ── Center: Controls ──────────────────────────────────────────────
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.wifi_tethering_rounded,
                          size: 20,
                          color: FlowyEngine.status.value ==
                                  ConnectionStatus.connected
                              ? Colors.green
                              : Colors.orange),
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (ctx) => const _ProviderSelectorSheet(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.shuffle_rounded,
                          size: 20,
                          color:
                              player.isShuffle ? accentColor : Colors.white60),
                      onPressed: player.toggleShuffle,
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, size: 36),
                      onPressed: player.skipToPrevious,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    _DesktopPlayButton(player: player),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 36),
                      onPressed: player.skipToNext,
                      color: Colors.white,
                    ),
                    IconButton(
                      icon: Icon(
                        player.repeatMode == FlowyRepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: player.repeatMode != FlowyRepeatMode.off
                            ? accentColor
                            : Colors.white60,
                        size: 20,
                      ),
                      onPressed: player.cycleRepeatMode,
                      mouseCursor: SystemMouseCursors.click,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _ProgressBar(player: player),
              ],
            ),
          ),
          const SizedBox(width: 40),
          // ── Right: Extra Controls ─────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _SmallGlassButton(
                  icon: Icons.playlist_play_rounded,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (ctx) => const QueueSheet(),
                    );
                  },
                ),
                const SizedBox(width: 12),
                const Icon(Icons.volume_up_rounded,
                    size: 20, color: Colors.white54),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 0),
                      activeTrackColor: accentColor,
                      inactiveTrackColor: Colors.white.withOpacity(0.1),
                    ),
                    child: Slider(
                      value: player.volume,
                      onChanged: (v) => player.setVolume(v),
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
}

class _SmallGlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _SmallGlassButton(
      {required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: FlowyTheme.glassDecoration(
        borderRadius: 10,
        opacity: 0.1,
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: iconColor ?? Colors.white70),
        onPressed: onTap,
        mouseCursor: SystemMouseCursors.click,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final PlayerProvider player;
  const _ProgressBar({required this.player});

  @override
  Widget build(BuildContext context) {
    final accentColor = player.dominantColor;
    final brightAccent = HSLColor.fromColor(accentColor)
        .withLightness(0.55)
        .withSaturation(1.0)
        .toColor();

    return Column(
      children: [
        // ── Thick Progress Bar ───────────────────────────────────────────────
        SizedBox(
          height: 14,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: brightAccent,
              inactiveTrackColor: Colors.white.withOpacity(0.12),
              thumbColor: Colors.white,
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: player.position.inSeconds.toDouble(),
              max: player.duration.inSeconds
                  .toDouble()
                  .clamp(1.0, double.infinity),
              onChanged: (val) => player.seekTo(Duration(seconds: val.toInt())),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // ── Timer Labels (Separated Below) ───────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(player.position),
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _formatDuration(player.duration),
                style: GoogleFonts.outfit(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _DesktopPlayButton extends StatelessWidget {
  final PlayerProvider player;
  const _DesktopPlayButton({required this.player});

  @override
  Widget build(BuildContext context) {
    if (player.isLoading) {
      return Container(
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(8),
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: player.togglePlayPause,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.black,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _ProviderSelectorSheet extends StatelessWidget {
  const _ProviderSelectorSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Seleccionar Proveedor',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            FlowyEngine.currentProviderName,
            style: TextStyle(
              fontSize: 14,
              color: FlowyEngine.status.value == ConnectionStatus.connected
                  ? Colors.green
                  : Colors.orange,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: FlowyEngine.providers.length,
              itemBuilder: (context, index) {
                final provider = FlowyEngine.providers[index];
                final isSelected = provider.url == FlowyEngine.currentApiUrl;

                return ListTile(
                  leading: Icon(
                    provider.type == ProviderType.invidious
                        ? Icons.video_library_rounded
                        : provider.type == ProviderType.piped
                            ? Icons.stream_rounded
                            : Icons.play_circle_rounded,
                    color: provider.isWorking ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    provider.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.w900 : FontWeight.normal,
                    ),
                  ),
                  subtitle: provider.isWorking && provider.latencyMs > 0
                      ? Text('${provider.latencyMs}ms')
                      : null,
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: Colors.green)
                      : provider.isWorking
                          ? null
                          : Icon(Icons.cancel_rounded,
                              color: Colors.redAccent.withOpacity(0.5)),
                  onTap: provider.isWorking
                      ? () async {
                          await FlowyEngine.switchProvider(provider);
                          if (context.mounted) Navigator.pop(context);
                        }
                      : null,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () async {
                await FlowyEngine.refresh();
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Escanear Proveedores'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
