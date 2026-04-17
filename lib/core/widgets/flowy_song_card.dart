import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../domain/entities/entities.dart';
import '../widgets/flowy_marquee.dart';
import '../theme/app_theme.dart';

class FlowySongCard extends StatefulWidget {
  final SongEntity song;
  final VoidCallback onTap;

  const FlowySongCard({super.key, required this.song, required this.onTap});

  @override
  State<FlowySongCard> createState() => _FlowySongCardState();
}

class _FlowySongCardState extends State<FlowySongCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isHovered 
                  ? Colors.white.withOpacity(0.08) 
                  : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isHovered 
                    ? Colors.white.withOpacity(0.15) 
                    : Colors.transparent,
                  width: 1,
                ),
                boxShadow: _isHovered ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  )
                ] : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: widget.song.bestThumbnail,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: Colors.grey[900]),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: _CardPlayButton(isHovered: _isHovered),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FlowyMarquee(
                    text: widget.song.title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800, 
                      fontSize: 14,
                      color: _isHovered ? Colors.white : Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.song.artist,
                    style: TextStyle(
                      color: _isHovered ? Colors.white70 : Colors.white54, 
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ),
      ),
    );
  }
}

class _CardPlayButton extends StatelessWidget {
  final bool isHovered;
  const _CardPlayButton({this.isHovered = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isHovered ? 44 : 40,
      height: isHovered ? 44 : 40,
      decoration: BoxDecoration(
        color: isHovered ? FlowyColors.brandAccent : FlowyColors.brandSeed,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isHovered ? 0.6 : 0.4),
            blurRadius: isHovered ? 15 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.play_arrow_rounded, 
        color: Colors.black, 
        size: isHovered ? 30 : 26
      ),
    );
  }
}
