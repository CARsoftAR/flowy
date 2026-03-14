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
  final VoidCallback onTap;

  const LyricsView({
    super.key,
    required this.song,
    required this.position,
    required this.onTap,
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
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: ScrollablePositionedList.builder(
                itemCount: lyrics.lines.length,
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
                itemBuilder: (context, index) {
                  final isSynced = lyrics.isSynced;
                  final isCurrent = index == _currentLineIndex;
                  final isActive = isSynced ? isCurrent : true;
                  
                  final double fontSize = isSynced ? (isActive ? 34 : 22) : 20;
                  final FontWeight fontWeight = isSynced ? (isActive ? FontWeight.w900 : FontWeight.w600) : FontWeight.w500;
                  final Color color = isActive ? Colors.white : Colors.white.withOpacity(0.2);
                  final double shadowBlur = isSynced ? (isActive ? 16 : 0) : 4;
                  final double scaleEnd = isSynced ? 1.02 : 1.0;

                  final line = lyrics.lines[index];

                  return AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                      color: color,
                      height: isSynced ? 1.4 : 1.6,
                      fontFamily: 'Outfit',
                      letterSpacing: (isActive && isSynced) ? 0.5 : 0,
                      shadows: isActive ? [
                        Shadow(color: Colors.white.withOpacity(0.5), blurRadius: shadowBlur)
                      ] : [],
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: isSynced ? 20 : 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          line.text.isEmpty ? (isSynced ? '•  •  •' : '') : line.text,
                        ),
                      ),
                    ).animate(target: isActive ? 1 : 0)
                     .fadeIn(duration: 800.ms, curve: Curves.easeOutSine)
                     .scale(begin: const Offset(1, 1), end: Offset(scaleEnd, scaleEnd), duration: 800.ms)
                     .blur(begin: const Offset(5, 5), end: const Offset(0, 0), duration: 800.ms),
                  );
                },
              ),
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
