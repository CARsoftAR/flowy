import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../features/player/presentation/providers/player_provider.dart';
import '../../features/player/presentation/pages/player_page.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/ambient_background.dart';
import '../../core/theme/premium_transitions.dart';

class TVShell extends StatefulWidget {
  final List<Widget> pages;
  final int selectedIndex;
  final Function(int) onIndexChanged;

  const TVShell({
    super.key,
    required this.pages,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  @override
  State<TVShell> createState() => _TVShellState();
}

class _TVShellState extends State<TVShell> {
  bool _isSidebarFocused = false;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AmbientBackground(
        imageUrl: song?.bestThumbnail,
        child: Stack(
          children: [
            // Mica effect
            Container(color: Colors.black.withOpacity(0.4)),
            
            Row(
              children: [
                // ── Sidebar (YouTube Style) ──────────────────────────────────
                _TVSidebar(
                  selectedIndex: widget.selectedIndex,
                  onIndexChanged: widget.onIndexChanged,
                  onFocusChange: (focused) => setState(() => _isSidebarFocused = focused),
                ),
                
                // ── Main Content Area ─────────────────────────────────────
                Expanded(
                  child: Column(
                    children: [
                      const _TVTopBar(),
                      Expanded(
                        child: FocusTraversalGroup(
                          child: IndexedStack(
                            index: widget.selectedIndex,
                            children: widget.pages,
                          ),
                        ),
                      ),
                      // ── TV Player Bar (Bottom) ──────────────────────────────
                      if (song != null) _TVPlayerBar(player: player),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TVSidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;
  final Function(bool) onFocusChange;

  const _TVSidebar({
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.onFocusChange,
  });

  @override
  State<_TVSidebar> createState() => _TVSidebarState();
}

class _TVSidebarState extends State<_TVSidebar> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) {
        setState(() => _isExpanded = focused);
        widget.onFocusChange(focused);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: _isExpanded ? 240 : 80,
        curve: Curves.easeOutCubic,
        color: Colors.black.withOpacity(_isExpanded ? 0.9 : 0.4),
        child: Column(
          children: [
            const SizedBox(height: 48),
            _TVSidebarItem(
              icon: Icons.home_rounded,
              label: 'Inicio',
              isSelected: widget.selectedIndex == 0,
              isExpanded: _isExpanded,
              onTap: () => widget.onIndexChanged(0),
            ),
            _TVSidebarItem(
              icon: Icons.search_rounded,
              label: 'Buscar',
              isSelected: widget.selectedIndex == 1,
              isExpanded: _isExpanded,
              onTap: () => widget.onIndexChanged(1),
            ),
            _TVSidebarItem(
              icon: Icons.library_music_rounded,
              label: 'Biblioteca',
              isSelected: widget.selectedIndex == 2,
              isExpanded: _isExpanded,
              onTap: () => widget.onIndexChanged(2),
            ),
            const Spacer(),
            _TVSidebarItem(
              icon: Icons.settings_rounded,
              label: 'Ajustes',
              isSelected: false,
              isExpanded: _isExpanded,
              onTap: () {},
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TVSidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  const _TVSidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  State<_TVSidebarItem> createState() => _TVSidebarItemState();
}

class _TVSidebarItemState extends State<_TVSidebarItem> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: _isFocused ? Colors.white.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: _isFocused ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  color: widget.isSelected || _isFocused ? Colors.white : Colors.white54,
                  size: 32,
                ),
                if (widget.isExpanded) ...[
                  const SizedBox(width: 16),
                  Text(
                    widget.label,
                    style: GoogleFonts.outfit(
                      color: widget.isSelected || _isFocused ? Colors.white : Colors.white54,
                      fontSize: 18,
                      fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TVTopBar extends StatelessWidget {
  const _TVTopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Row(
        children: [
          Text(
            'Flowy',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const Spacer(),
          const Icon(Icons.cast, color: Colors.white54, size: 28),
          const SizedBox(width: 24),
          const CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=flowy'),
          ),
        ],
      ),
    );
  }
}

class _TVPlayerBar extends StatelessWidget {
  final PlayerProvider player;
  const _TVPlayerBar({required this.player});

  @override
  Widget build(BuildContext context) {
    final song = player.currentSong!;
    final accent = player.dominantColor;

    return Focus(
      child: Container(
        height: 140,
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: song.bestThumbnail,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    maxLines: 1,
                  ),
                  Text(
                    song.artist,
                    style: const TextStyle(fontSize: 16, color: Colors.white60),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 48),
            _TVControlButton(
              icon: Icons.skip_previous_rounded,
              onTap: player.skipToPrevious,
            ),
            const SizedBox(width: 16),
            _TVPlayButton(player: player),
            const SizedBox(width: 16),
            _TVControlButton(
              icon: Icons.skip_next_rounded,
              onTap: player.skipToNext,
            ),
            const SizedBox(width: 32),
            _TVControlButton(
              icon: Icons.fullscreen_rounded,
              onTap: () {
                Navigator.of(context).push(PremiumTransitions.slideUp(const PlayerPage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TVControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TVControlButton({required this.icon, required this.onTap});

  @override
  State<_TVControlButton> createState() => _TVControlButtonState();
}

class _TVControlButtonState extends State<_TVControlButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: _isFocused ? Colors.white : Colors.white10,
            shape: BoxShape.circle,
            border: _isFocused ? Border.all(color: Colors.white, width: 3) : null,
          ),
          child: Icon(
            widget.icon,
            color: _isFocused ? Colors.black : Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}

class _TVPlayButton extends StatefulWidget {
  final PlayerProvider player;
  const _TVPlayButton({required this.player});

  @override
  State<_TVPlayButton> createState() => _TVPlayButtonState();
}

class _TVPlayButtonState extends State<_TVPlayButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.player.togglePlayPause,
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        borderRadius: BorderRadius.circular(40),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _isFocused ? Colors.white : widget.player.dominantColor,
            shape: BoxShape.circle,
            boxShadow: _isFocused ? [BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 20)] : null,
          ),
          child: Icon(
            widget.player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: _isFocused ? Colors.black : Colors.white,
            size: 48,
          ),
        ),
      ),
    );
  }
}
