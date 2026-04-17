import 'package:flutter/material.dart';

class FlowyMarquee extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double pixelsPerSecond;
  final Duration pauseDuration;
  final double gap;

  const FlowyMarquee({
    super.key,
    required this.text,
    this.style,
    this.pixelsPerSecond = 50.0,
    this.pauseDuration = const Duration(seconds: 3),
    this.gap = 50.0,
  });

  @override
  State<FlowyMarquee> createState() => _FlowyMarqueeState();
}

class _FlowyMarqueeState extends State<FlowyMarquee> {
  late ScrollController _scrollController;
  bool _isScrolling = false;
  bool _doesOverflow = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void didUpdateWidget(FlowyMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _stopAndReset();
    }
  }

  void _stopAndReset() {
    _isScrolling = false;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    setState(() => _doesOverflow = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  void _checkOverflow() {
    if (!mounted || !_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 0) {
      setState(() => _doesOverflow = true);
      _startAnimation();
    }
  }

  Future<void> _startAnimation() async {
    if (!mounted || _isScrolling || !_doesOverflow) return;
    _isScrolling = true;

    while (mounted && _isScrolling) {
      await Future.delayed(widget.pauseDuration);
      if (!mounted || !_isScrolling) break;

      // We calculate the width of the first text + gap
      // In our Row, it would be exactly the total scroll width / 1 (since we have 2 copies)
      // Actually, maxScrollExtent = (TextWidth * 2 + Gap) - ViewportWidth.
      // To loop seamlessly, we need to scroll exactly (TextWidth + Gap).
      
      // Let's find the text width
      final textPainter = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      
      final textWidth = textPainter.width;
      final scrollDistance = textWidth + widget.gap;
      
      final duration = Duration(
        milliseconds: (scrollDistance / widget.pixelsPerSecond * 1000).toInt(),
      );

      await _scrollController.animateTo(
        scrollDistance,
        duration: duration,
        curve: Curves.linear,
      );

      if (!mounted || !_isScrolling) break;

      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _isScrolling = false;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            softWrap: false,
          ),
          if (_doesOverflow) ...[
            SizedBox(width: widget.gap),
            Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              softWrap: false,
            ),
          ],
        ],
      ),
    );
  }
}
