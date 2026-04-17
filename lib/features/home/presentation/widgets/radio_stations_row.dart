import 'dart:convert';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_custom_radio_dialog.dart';
import '../../../../domain/entities/radio_station.dart';
import '../../../../domain/entities/entities.dart';
import '../../../player/presentation/providers/player_provider.dart';
import 'package:uuid/uuid.dart';

class RadioStationsRow extends StatefulWidget {
  const RadioStationsRow({super.key});

  @override
  State<RadioStationsRow> createState() => _RadioStationsRowState();
}

class _RadioStationsRowState extends State<RadioStationsRow> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = true;
  List<RadioStation> _allStations = [];
  static const String _storageKey = 'custom_radios';

  @override
  void initState() {
    super.initState();
    _loadStations();
    _scrollController.addListener(_updateScrollButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollButtons());
  }

  Future<void> _loadStations() async {
    final prefs = await SharedPreferences.getInstance();
    final customJson = prefs.getStringList(_storageKey) ?? [];
    
    final List<RadioStation> customStations = customJson.map((j) {
      final map = jsonDecode(j);
      return RadioStation(
        id: map['id'],
        name: map['name'],
        genre: map['genre'],
        streamUrl: map['streamUrl'],
        gradientColors: (map['colors'] as List).map((c) => Color(c)).toList(),
      );
    }).toList();

    setState(() {
      _allStations = customStations;
    });
  }

  Future<void> _saveCustomRadios() async {
    final prefs = await SharedPreferences.getInstance();
    
    final jsonList = _allStations.map((s) => jsonEncode({
      'id': s.id,
      'name': s.name,
      'genre': s.genre,
      'streamUrl': s.streamUrl,
      'colors': s.gradientColors.map((c) => c.value).toList(),
    })).toList();
    
    await prefs.setStringList(_storageKey, jsonList);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!_scrollController.hasClients) return;
    final canScrollLeft = _scrollController.offset > 0;
    final canScrollRight = _scrollController.offset < _scrollController.position.maxScrollExtent;
    if (canScrollLeft != _canScrollLeft || canScrollRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canScrollLeft;
        _canScrollRight = canScrollRight;
      });
    }
  }

  void _scroll(bool left) {
    final offset = left ? _scrollController.offset - 400 : _scrollController.offset + 400;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _addNewRadio() async {
    final radio = await showAddCustomRadioDialog(context);
    if (radio != null) {
      setState(() {
        _allStations.add(radio);
      });
      await _saveCustomRadios();
    }
  }

  Future<void> _editRadio(RadioStation station) async {
    final radio = await showAddCustomRadioDialog(context, editingStation: station);
    if (radio != null) {
      setState(() {
        final index = _allStations.indexWhere((s) => s.id == station.id);
        if (index != -1) _allStations[index] = radio;
      });
      await _saveCustomRadios();
    }
  }

  Future<void> _deleteRadio(RadioStation station) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('¿Eliminar radio?', style: TextStyle(color: Colors.white)),
        content: Text('¿Estás seguro de que quieres eliminar "${station.name}"?', 
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), 
              child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _allStations.removeWhere((s) => s.id == station.id);
      });
      await _saveCustomRadios();
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Radios en Vivo',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton.icon(
                onPressed: _addNewRadio,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 160,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: ListView.separated(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _allStations.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _AddRadioCard(onTap: _addNewRadio);
                    }
                    final radio = _allStations[index - 1];
                    return _RadioCard(
                      station: radio,
                      onTap: () => _playRadio(player, radio),
                      onEdit: () => _editRadio(radio),
                      onDelete: () => _deleteRadio(radio),
                    ).animate().fadeIn(delay: (50 * index).ms).scale(begin: const Offset(0.8, 0.8));
                  },
                ),
              ),
            ),
            if (_canScrollLeft)
              Positioned(
                left: 10,
                child: _CarouselButton(
                  icon: Icons.chevron_left_rounded,
                  onPressed: () => _scroll(true),
                ),
              ),
            if (_canScrollRight)
              Positioned(
                right: 10,
                child: _CarouselButton(
                  icon: Icons.chevron_right_rounded,
                  onPressed: () => _scroll(false),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _playRadio(PlayerProvider player, RadioStation radio) {
    final song = SongEntity(
      id: 'radio_${radio.id}',
      title: radio.name,
      artist: radio.genre,
      streamUrl: radio.streamUrl,
      isDirectStream: true,
      isLive: true,
      thumbnailUrl: radio.thumbnailUrl,
    );
    player.playSong(song);
  }
}

class _CarouselButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CarouselButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    ).animate().fadeIn().scale();
  }
}

class _RadioCard extends StatefulWidget {
  final RadioStation station;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _RadioCard({
    required this.station,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<_RadioCard> createState() => _RadioCardState();
}

class _RadioCardState extends State<_RadioCard> {
  bool _isHovered = false;

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E), // Flowy surface color
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_rounded, color: Colors.indigoAccent),
              ),
              title: const Text('Editar Radio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                widget.onEdit?.call();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              ),
              title: const Text('Eliminar Radio', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                widget.onDelete?.call();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: () => _showOptions(context),
        child: Container(
          width: 140,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.station.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.station.gradientColors.first.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  widget.station.icon,
                  size: 100,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.station.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.station.genre,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
                      SizedBox(width: 2),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Hover Controls (Desktop)
              if (_isHovered && (widget.onEdit != null || widget.onDelete != null))
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (widget.onEdit != null)
                          Tooltip(
                            message: 'Editar Radio',
                            child: IconButton(
                              icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                              onPressed: widget.onEdit,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        if (widget.onDelete != null)
                          Tooltip(
                            message: 'Borrar Radio',
                            child: IconButton(
                              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
                              onPressed: widget.onDelete,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: -0.2),
                ),
              
              // Mobile / Touch Menu Trigger
              if ((widget.onEdit != null || widget.onDelete != null) && !_isHovered)
                Positioned(
                  top: 4,
                  left: 4,
                  child: GestureDetector(
                    onTap: () => _showOptions(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 16),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddRadioCard extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddRadioCard({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Agregar Radio',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
