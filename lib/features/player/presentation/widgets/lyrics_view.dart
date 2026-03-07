import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../data/datasources/lyrics_datasource.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LyricsView — Auto-scrolling synced lyrics display
// ─────────────────────────────────────────────────────────────────────────────

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
  final ScrollController _scrollController = ScrollController();
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
      _lyrics = null;
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
    if (!_scrollController.hasClients) return;
    const itemHeight = 52.0;
    final targetOffset = (_currentLineIndex * itemHeight) -
        (_scrollController.position.viewportDimension / 2) +
        itemHeight;
    _scrollController.animateTo(
      targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_outlined, color: Colors.white30, size: 48),
            const SizedBox(height: 12),
            Text(
              'Letras no disponibles',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white38,
                  ),
            ),
          ],
        ),
      );
    }

    final lyrics = _lyrics!;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      itemCount: lyrics.lines.length,
      itemBuilder: (context, index) {
        final isActive = index == _currentLineIndex && lyrics.isSynced;
        final line = lyrics.lines[index];

        return AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontSize: isActive ? 22 : 18,
            fontWeight:
                isActive ? FontWeight.w700 : FontWeight.w400,
            color: isActive ? Colors.white : Colors.white38,
            height: 1.4,
            fontFamily: 'Outfit',
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              line.text.isEmpty ? '•  •  •' : line.text,
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
