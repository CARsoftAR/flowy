
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../data/datasources/lyrics_datasource.dart';

class LyricsView extends StatefulWidget {
  final SongEntity song;
  final Duration position;

  const LyricsView({
    super.key,
    required this.song,
    required this.position,
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  
  LyricsEntity? _lyrics;
  bool _loading = true;
  String? _error;
  int _currentLineIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void didUpdateWidget(LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _loadLyrics();
    }
    if (_lyrics != null && _lyrics!.isSynced) {
      _updateCurrentLine();
    }
  }

  Future<void> _loadLyrics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final source = LyricsDataSource();
    final result = await source.getLyrics(
      widget.song.id,
      widget.song.title,
      widget.song.artist,
    );

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = failure.message;
      }),
      (lyrics) => setState(() {
        _loading = false;
        _lyrics = lyrics;
      }),
    );
  }

  void _updateCurrentLine() {
    final lyrics = _lyrics;
    if (lyrics == null || !lyrics.isSynced) return;

    final pos = widget.position;
    int idx = 0;
    for (int i = 0; i < lyrics.lines.length; i++) {
      if (lyrics.lines[i].timestamp <= pos) idx = i;
    }

    if (idx != _currentLineIndex) {
      _currentLineIndex = idx;
      _scrollToCurrentLine();
    }
  }

  void _scrollToCurrentLine() {
    if (!_itemScrollController.isAttached) return;
    _itemScrollController.scrollTo(
      index: _currentLineIndex,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      alignment: 0.35, // Position active line slightly above center
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _lyrics == null) {
      return _buildPlaceholder('Letras no disponibles');
    }

    final lyrics = _lyrics!;

    return ScrollablePositionedList.builder(
      itemCount: lyrics.lines.length,
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      itemBuilder: (context, index) {
        final isActive = index == _currentLineIndex && lyrics.isSynced;
        final line = lyrics.lines[index];

        return GestureDetector(
          onTap: () {
            // Future: seek to this line
          },
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: isActive ? 32 : 24,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive ? Colors.white : Colors.white24,
              height: 1.5,
              fontFamily: 'Outfit',
              shadows: isActive ? [
                Shadow(
                  color: Colors.white.withOpacity(0.5),
                  blurRadius: 12,
                )
              ] : [],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  line.text.isEmpty ? '•  •  •' : line.text,
                ),
              ),
            ).animate(target: isActive ? 1 : 0)
             .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05))
             .blur(begin: const Offset(2, 2), end: const Offset(0, 0)),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lyrics_outlined, color: Colors.white10, size: 64),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white24, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
