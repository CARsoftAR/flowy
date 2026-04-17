import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../domain/entities/entities.dart';
import '../theme/app_theme.dart';

class FlowyPlaylistCard extends StatefulWidget {
  final PlaylistEntity playlist;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isHighlighted;

  const FlowyPlaylistCard({
    super.key, 
    required this.playlist, 
    required this.onTap,
    this.onLongPress,
    this.isHighlighted = false,
  });

  @override
  State<FlowyPlaylistCard> createState() => _FlowyPlaylistCardState();
}

class _FlowyPlaylistCardState extends State<FlowyPlaylistCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: (_isHovered || widget.isHighlighted) 
                      ? Colors.white.withOpacity(0.12) 
                      : Colors.white.withOpacity(0.05),
                    border: Border.all(
                      color: widget.isHighlighted 
                        ? Colors.cyanAccent.withOpacity(0.8)
                        : (_isHovered 
                          ? Colors.white.withOpacity(0.2) 
                          : Colors.transparent),
                      width: widget.isHighlighted ? 3 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.isHighlighted 
                          ? Colors.cyanAccent.withOpacity(0.4)
                          : Colors.black.withOpacity(_isHovered ? 0.6 : 0.4),
                        blurRadius: _isHovered ? 30 : 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Builder(
                        builder: (context) {
                          final List<String> allThumbs = [];
                          
                          // 1. Own thumbnail
                          if (widget.playlist.thumbnailUrl != null && widget.playlist.thumbnailUrl!.trim().isNotEmpty) {
                            allThumbs.add(widget.playlist.thumbnailUrl!.trim());
                          }
                          
                          // 2. Direct tracks thumbnails
                          for (var s in widget.playlist.tracks) {
                            final t = s.bestThumbnail;
                            if (t.isNotEmpty && !allThumbs.contains(t)) {
                              allThumbs.add(t);
                            }
                            if (allThumbs.length >= 4) break;
                          }
                          
                          // 3. Sub-playlists thumbnails (direct or deep)
                          if (allThumbs.length < 4) {
                            for (var sub in widget.playlist.subPlaylists) {
                              // Try sub-playlist's own thumb
                              final subT = sub.thumbnailUrl ?? (sub.tracks.isNotEmpty ? sub.tracks.first.bestThumbnail : '');
                              if (subT.isNotEmpty && !allThumbs.contains(subT)) {
                                allThumbs.add(subT);
                              }
                              if (allThumbs.length >= 4) break;
                              
                              // If still need more, peek into sub-playlist's songs
                              for (var s in sub.tracks) {
                                final st = s.bestThumbnail;
                                if (st.isNotEmpty && !allThumbs.contains(st)) {
                                  allThumbs.add(st);
                                }
                                if (allThumbs.length >= 4) break;
                              }
                              if (allThumbs.length >= 4) break;
                            }
                          }

                          if (allThumbs.isEmpty) {
                            return Center(
                              child: Icon(
                                widget.playlist.isFolder ? Icons.folder_rounded : Icons.music_note_rounded,
                                size: 64,
                                color: Colors.white.withOpacity(0.2),
                              ),
                            );
                          }

                          if (allThumbs.length >= 4 || (widget.playlist.isFolder && allThumbs.length >= 2)) {
                            return GridView.count(
                              crossAxisCount: 2,
                              padding: EdgeInsets.zero,
                              physics: const NeverScrollableScrollPhysics(),
                              children: allThumbs.take(4).map((t) => CachedNetworkImage(
                                imageUrl: t,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.05)),
                                errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 20),
                              )).toList(),
                            );
                          }

                          return CachedNetworkImage(
                            imageUrl: allThumbs.first,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.05)),
                            errorWidget: (context, url, error) => const Icon(Icons.music_note_rounded, size: 32),
                          );
                        },
                      ),
                      
                      // Bottom bar with tracks count
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Text(
                            widget.playlist.isFolder
                              ? '${widget.playlist.subPlaylists.length} elementos'
                              : '${widget.playlist.tracks.length} canciones',
                            style: GoogleFonts.outfit(
                              color: Colors.white70, 
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      
                      // Animated Glow Overlay
                      if (_isHovered)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withOpacity(0.05),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.playlist.title,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800, 
                        fontSize: 15,
                        color: _isHovered ? Colors.white : Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.playlist.isFolder 
                        ? 'Carpeta • Flowy' 
                        : (widget.playlist.id.startsWith('RD') 
                            ? 'Mix • YouTube' 
                            : 'Playlist • Flowy'),
                      style: const TextStyle(
                        color: Colors.white38, 
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
