import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class InterestCard extends StatefulWidget {
  final String id;
  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int index;

  const InterestCard({
    super.key,
    required this.id,
    required this.title,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
    this.onLongPress,
    required this.index,
  });

  @override
  State<InterestCard> createState() => _InterestCardState();
}

class _InterestCardState extends State<InterestCard> with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    setState(() => _scale = 0.95);
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _scale = 1.0);
  }

  void _onTapCancel() {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      onLongPress: () {
        if (widget.onLongPress != null) {
          HapticFeedback.heavyImpact();
          widget.onLongPress!();
        }
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Hero(
          tag: 'interest_${widget.id}',
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: widget.gradientColors.last.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Decorative background icon
                Positioned(
                  right: -15,
                  bottom: -15,
                  child: Opacity(
                    opacity: 0.15,
                    child: FaIcon(
                      widget.icon,
                      size: 90,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: FaIcon(
                          widget.icon, 
                          color: Colors.white, 
                          size: 20
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: Colors.transparent,
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
          .animate(delay: Duration(milliseconds: widget.index * 40))
          .fadeIn(duration: 400.ms, curve: Curves.easeOutQuint)
          .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack)
          .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuint),
        ),
      ),
    );
  }
}
