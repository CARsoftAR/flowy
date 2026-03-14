import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../data/datasources/lyrics_datasource.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/skeleton_shimmer.dart';

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
      HapticEngine.selection(); // Subtle feedback when lyric changes
    }
  }

  void _scrollToCurrentLine() {
    if (!_itemScrollController.isAttached) return;
    _itemScrollController.scrollTo(
      index: _currentLineIndex,
      duration: const Duration(milliseconds: 800),
      curve: Curves.fastLinearToSlowEaseIn,
      alignment: 0.3, 
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(6, (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: SkeletonShimmer.rect(
              width: 150 + (i % 3) * 100, 
              height: 32,
              borderRadius: 16,
            ),
          )),
        ),
      );
    }

    if (_error != null || _lyrics == null) {
      return _buildPlaceholder('Letras no disponibles');
    }

    final lyrics = _lyrics!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 40,
            spreadRadius: -5,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.15, 0.85, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ScrollablePositionedList.builder(
              itemCount: lyrics.lines.length,
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
              itemBuilder: (context, index) {
                final isActive = index == _currentLineIndex && lyrics.isSynced;
                final line = lyrics.lines[index];

                return GestureDetector(
                  onTap: () {
                    // Future: seek to this line
                  },
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.fastOutSlowIn,
                    style: TextStyle(
                      fontSize: isActive ? 34 : 22,
                      fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                      color: isActive ? Colors.white : Colors.white.withOpacity(0.2),
                      height: 1.4,
                      fontFamily: 'Outfit',
                      letterSpacing: isActive ? 0.5 : 0,
                      shadows: isActive ? [
                        Shadow(color: Colors.white.withOpacity(0.6), blurRadius: 16)
                      ] : [],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          line.text.isEmpty ? '•  •  •' : line.text,
                        ),
                      ),
                    ).animate(target: isActive ? 1 : 0)
                     .scale(begin: const Offset(1, 1), end: const Offset(1.02, 1.02))
                     .blur(begin: const Offset(3, 3), end: const Offset(0, 0)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
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
