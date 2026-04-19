
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

class MainScreenTV extends StatefulWidget {
  final List<Widget> pages;
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;

  const MainScreenTV({
    super.key,
    required this.pages,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  @override
  State<MainScreenTV> createState() => _MainScreenTVState();
}

class _SideMenuFocusOrder {
  static const search = 1;
  static const home = 2;
  static const library = 3;
  static const radio = 4;
  static const settings = 5;
}

class _MainScreenTVState extends State<MainScreenTV> {
  bool _isSideMenuFocused = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          _SideMenuTV(
            selectedIndex: widget.selectedIndex,
            onIndexChanged: widget.onIndexChanged,
            onFocusChange: (focused) {
              setState(() => _isSideMenuFocused = focused);
            },
          ),
          Expanded(
            child: FocusTraversalGroup(
              child: IndexedStack(
                index: widget.selectedIndex,
                children: widget.pages,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideMenuTV extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;
  final Function(bool) onFocusChange;

  const _SideMenuTV({
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.onFocusChange,
  });

  @override
  State<_SideMenuTV> createState() => _SideMenuTVState();
}

class _SideMenuTVState extends State<_SideMenuTV> {
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
        curve: Curves.easeInOutQuad,
        width: _isExpanded ? 260 : 100, // Ajustado para expansión fluida de TV
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          border: Border(
            right: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  _buildLogo(_isExpanded),
                  const SizedBox(height: 48),
                  
                  _buildSidebarItem(0, Icons.search, 'BUSCAR', _SideMenuFocusOrder.search),
                  _buildSidebarItem(1, Icons.home, 'INICIO', _SideMenuFocusOrder.home),
                  _buildSidebarItem(2, Icons.library_music, 'BIBLIOTECA', _SideMenuFocusOrder.library),
                  _buildSidebarItem(3, Icons.radio, 'ESTACIONES', _SideMenuFocusOrder.radio),
                  
                  const Spacer(),
                  
                  _buildSidebarItem(4, Icons.settings, 'AJUSTES', _SideMenuFocusOrder.settings),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label, int order) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(order.toDouble()),
      child: _SideMenuItemTV(
        icon: icon,
        label: label,
        isSelected: widget.selectedIndex == index,
        isExpanded: _isExpanded,
        onTap: () => widget.onIndexChanged(index),
      ),
    );
  }

  Widget _buildLogo(bool expanded) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: expanded
          ? Text(
              'FLOWY',
              key: const ValueKey('logo_expanded'),
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            )
          : Container(
              key: const ValueKey('logo_collapsed'),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: FlowyColors.brandSeed,
                borderRadius: BorderRadius.circular(14),
                boxShadow: FlowyTheme.glowShadow(FlowyColors.brandSeed, intensity: 0.5),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
            ),
    );
  }
}

class ActivateIntent extends Intent {
  const ActivateIntent();
}

class _SideMenuItemTV extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  const _SideMenuItemTV({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  State<_SideMenuItemTV> createState() => _SideMenuItemTVState();
}

class _SideMenuItemTVState extends State<_SideMenuItemTV> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.space): const ActivateIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (intent) => widget.onTap()),
          },
          child: Focus(
            onFocusChange: (f) => setState(() => _hasFocus = f),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(16),
                child: AnimatedScale(
                  scale: _hasFocus ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    decoration: BoxDecoration(
                      color: _hasFocus 
                          ? Colors.blueAccent.withOpacity(0.3) // Feedback Glow Azul
                          : (widget.isSelected ? FlowyColors.brandSeed.withOpacity(0.2) : Colors.transparent),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _hasFocus ? Colors.blueAccent : (widget.isSelected ? FlowyColors.brandSeed : Colors.transparent),
                        width: _hasFocus ? 2.5 : 1.5,
                      ),
                      boxShadow: _hasFocus 
                          ? [
                              BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
                            ] 
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: widget.isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.icon,
                          color: _hasFocus || widget.isSelected ? Colors.white : Colors.white24,
                          size: 26,
                        ),
                        if (widget.isExpanded) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              widget.label,
                              style: GoogleFonts.outfit(
                                color: _hasFocus || widget.isSelected ? Colors.white : Colors.white24,
                                fontSize: 16,
                                fontWeight: widget.isSelected || _hasFocus ? FontWeight.w900 : FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
