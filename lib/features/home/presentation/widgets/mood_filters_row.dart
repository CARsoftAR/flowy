import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/repositories/repositories.dart';
import '../../../../core/di/injection.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../library/presentation/providers/library_provider.dart';


class MoodFiltersRow extends StatefulWidget {
  const MoodFiltersRow({super.key});

  @override
  State<MoodFiltersRow> createState() => _MoodFiltersRowState();
}

class _MoodFiltersRowState extends State<MoodFiltersRow> {
  final MusicRepository _repo = sl<MusicRepository>();
  String? _loadingMood;
  List<Map<String, dynamic>> _customMoods = [];
  bool _initialized = false;

  final List<Map<String, dynamic>> _defaultMoods = [
    {
      'label': 'Día de lluvia',
      'icon': Icons.water_drop_rounded,
      'color': Colors.blueAccent,
      'query': 'chill lofi rain relaxing piano acoustic',
    },
    {
      'label': 'Modo Bestia',
      'icon': Icons.fitness_center_rounded,
      'color': Colors.deepOrange,
      'query': 'gym hardstyle phonk workout heavy metal energy',
    },
    {
      'label': 'Corazón Roto',
      'icon': Icons.heart_broken_rounded,
      'color': Colors.purpleAccent,
      'query': 'sad songs heartbroken baladas tristes',
    },
    {
      'label': 'Viaje en Auto',
      'icon': Icons.directions_car_rounded,
      'color': Colors.teal,
      'query': 'roadtrip driving music pop rock classics',
    },
    {
      'label': 'Fiesta',
      'icon': Icons.celebration_rounded,
      'color': Colors.amber,
      'query': 'party dance reggaeton electronic hits mix',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomMoods();
  }

  Future<void> _loadCustomMoods() async {
    final prefs = await SharedPreferences.getInstance();
    final String? moodsJson = prefs.getString('custom_moods');
    if (moodsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(moodsJson);
        setState(() {
          _customMoods = decoded.map((m) => Map<String, dynamic>.from(m)).toList();
          _initialized = true;
        });
      } catch (e) {
        debugPrint('Error loading custom moods: $e');
        setState(() => _initialized = true);
      }
    } else {
      setState(() => _initialized = true);
    }
  }

  Future<void> _saveCustomMoods() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_moods', jsonEncode(_customMoods));
  }

  Map<String, dynamic> _interpretMood(String name) {
    final lower = name.toLowerCase();
    IconData icon = Icons.auto_awesome_rounded;
    Color color = Colors.grey;

    if (lower.contains('lluvia') || lower.contains('relaj') || lower.contains('dormir') || lower.contains('paz')) {
      icon = Icons.water_drop_rounded;
      color = Colors.blueAccent;
    } else if (lower.contains('gym') || lower.contains('entren') || lower.contains('bestia') || lower.contains('fuerza')) {
      icon = Icons.fitness_center_rounded;
      color = Colors.deepOrange;
    } else if (lower.contains('triste') || lower.contains('roto') || lower.contains('llorar') || lower.contains('soledad')) {
      icon = Icons.heart_broken_rounded;
      color = Colors.purpleAccent;
    } else if (lower.contains('auto') || lower.contains('viaje') || lower.contains('ruta')) {
      icon = Icons.directions_car_rounded;
      color = Colors.teal;
    } else if (lower.contains('fiesta') || lower.contains('baile') || lower.contains('joda') || lower.contains('reunion')) {
      icon = Icons.celebration_rounded;
      color = Colors.amber;
    } else if (lower.contains('estudiar') || lower.contains('leer') || lower.contains('foco') || lower.contains('concentracion')) {
      icon = Icons.menu_book_rounded;
      color = Colors.indigoAccent;
    } else if (lower.contains('gamer') || lower.contains('juego') || lower.contains('viciar')) {
      icon = Icons.sports_esports_rounded;
      color = Colors.greenAccent;
    } else if (lower.contains('cafe') || lower.contains('mañana')) {
      icon = Icons.coffee_rounded;
      color = Colors.brown;
    }

    return {
      'label': name,
      'icon': icon.codePoint,
      'color': color.value,
      'query': '$name music vibes playlist',
    };
  }

  Future<void> _addNewMood() async {
    final controller = TextEditingController();
    final theme = Theme.of(context);

    final String? name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Nuevo Estado de Ánimo', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Escribe cómo te sientes y crearemos una radio para vos.', 
              style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ej: Noche de Verano, Chill para estudiar...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Crear Radio', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final newMood = _interpretMood(name);
      setState(() {
        _customMoods.insert(0, newMood);
      });
      await _saveCustomMoods();
    }
  }

  Future<void> _playMoodRadio(Map<String, dynamic> mood) async {
    if (_loadingMood != null) return;
    
    setState(() => _loadingMood = mood['label']);
    
    final Color moodColor = mood['color'] is int ? Color(mood['color']) : (mood['color'] as Color);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16, height: 16, 
              child: CircularProgressIndicator(strokeWidth: 2, color: moodColor),
            ),
            const SizedBox(width: 12),
            Text('Generando radio: ${mood['label']}...'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final result = await _repo.search(mood['query']);
    
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _loadingMood = null);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar la radio: ${failure.message}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      (searchResult) {
        setState(() => _loadingMood = null);
        
        final songs = searchResult.songs;
        if (songs.isEmpty) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No encontramos música para este estado de ánimo.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        songs.shuffle();

        final player = context.read<PlayerProvider>();
        final library = context.read<LibraryProvider>();
        player.playSong(songs.first, queue: songs);
        library.addToHistory(songs.first);

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Radio iniciada! Disfruta tu ${mood['label']}'),
            backgroundColor: moodColor.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const SizedBox(height: 48);

    final allMoods = [..._customMoods, ..._defaultMoods];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: allMoods.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _MoodChip(
              label: 'Nuevo Mood',
              icon: Icons.add_rounded,
              color: Colors.white54,
              onTap: _addNewMood,
            ).animate().fadeIn().scale();
          }

          final mood = allMoods[index - 1];
          final isLoading = _loadingMood == mood['label'];
          final IconData iconData = mood['icon'] is int ? IconData(mood['icon'], fontFamily: 'MaterialIcons') : (mood['icon'] as IconData);
          final Color moodColor = mood['color'] is int ? Color(mood['color']) : (mood['color'] as Color);
          
          return _MoodChip(
            label: mood['label'],
            icon: iconData,
            color: moodColor,
            isLoading: isLoading,
            onTap: () => _playMoodRadio(mood),
            onLongPress: index <= _customMoods.length ? () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1A24),
                  title: const Text('Eliminar Mood'),
                  content: Text('¿Quieres borrar la radio "${mood['label']}"?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, borrar', style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              );
              if (confirm == true) {
                setState(() {
                  _customMoods.removeAt(index - 1);
                });
                await _saveCustomMoods();
              }
            } : null,
          ).animate(delay: (index * 50).ms).fadeIn().slideX(begin: 0.2, end: 0);
        },
      ),
    );
  }
}

class _MoodChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _MoodChip({
    required this.label,
    required this.icon,
    required this.color,
    this.isLoading = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<_MoodChip> createState() => _MoodChipState();
}

class _MoodChipState extends State<_MoodChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _isHovered ? widget.color.withOpacity(0.2) : widget.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isHovered ? widget.color.withOpacity(0.5) : widget.color.withOpacity(0.25),
                width: 1.5,
              ),
              boxShadow: _isHovered ? [
                BoxShadow(
                  color: widget.color.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ] : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isLoading)
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: widget.color),
                  )
                else
                  Icon(widget.icon, size: 18, color: _isHovered ? widget.color : widget.color.withOpacity(0.8)),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(_isHovered ? 1.0 : 0.85),
                    fontWeight: _isHovered ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
