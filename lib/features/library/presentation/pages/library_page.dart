import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:flowy/domain/entities/entities.dart';
import 'package:flowy/features/player/presentation/providers/player_provider.dart';
import 'package:flowy/features/library/presentation/providers/library_provider.dart';
import 'package:flowy/features/library/presentation/providers/download_provider.dart';
import 'package:flowy/features/stats/presentation/providers/stats_provider.dart';
import 'package:flowy/features/home/presentation/widgets/song_tile.dart';
import 'package:flowy/features/home/presentation/widgets/section_header.dart';
import 'package:flowy/features/library/presentation/widgets/spotify_import_dialog.dart';
import 'package:flowy/features/library/presentation/widgets/youtube_import_dialog.dart';
import '../../../../core/widgets/flowy_song_card.dart';
import '../../../../core/widgets/flowy_playlist_card.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  int _viewIndex = 0;
  String? _selectedPlaylistId;
  final List<String> _folderIds = [];

  PlaylistEntity? _resolveFolder(List<PlaylistEntity> list, String id) {
    for (var p in list) {
      if (p.id == id) return p;
      if (p.isFolder) {
        final found = _resolveFolder(p.subPlaylists, id);
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<void> _showCreatePlaylistDialog(BuildContext context, {String? parentFolderId}) async {
    final controller = TextEditingController();
    final scheme = Theme.of(context).colorScheme;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color.lerp(scheme.surface, Colors.black, 0.7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Nueva Playlist', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF7C4DFF))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nombre de tu lista...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                // By user request, folders and playlists are now unified. 
                // We create a "Folder" by default so it can contain others.
                context.read<LibraryProvider>().createFolder(name, parentFolderId: parentFolderId);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final currentFolderId = _folderIds.isNotEmpty ? _folderIds.last : null;
    final PlaylistEntity? currentFolder = currentFolderId != null 
      ? _resolveFolder(library.playlists, currentFolderId)
      : null;

    // Safety net: sync view index based on current selection type
    if (_viewIndex == 0 && _folderIds.isNotEmpty) {
      final p = _resolveFolder(library.playlists, _folderIds.last);
      if (p != null && !p.isFolder) {
        // It's no longer a folder, it's a playlist (e.g. after import merge)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _selectedPlaylistId = _folderIds.removeLast();
            _viewIndex = 4;
          });
        });
      }
    }

    // Opposite: if we are in playlist view but it's now a folder, redirect to grid
    if (_viewIndex == 4 && _selectedPlaylistId != null) {
      final p = _resolveFolder(library.playlists, _selectedPlaylistId!);
      if (p != null && p.isFolder) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _folderIds.add(_selectedPlaylistId!);
            _selectedPlaylistId = null;
            _viewIndex = 0;
          });
        });
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 32, bottom: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.surface.withOpacity(0.8), scheme.surface.withOpacity(0.4), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      if (_folderIds.isNotEmpty && _viewIndex == 0)
                        IconButton(
                          onPressed: () => setState(() => _folderIds.removeLast()),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        ),
                      DragTarget<String>(
                        onAccept: (data) {
                          if (_viewIndex == 0) {
                            final targetFolderId = _folderIds.length > 1 
                                ? _folderIds[_folderIds.length - 2] 
                                : null;
                            context.read<LibraryProvider>().movePlaylistToFolder(data, targetFolderId);
                          }
                        },
                        builder: (context, candidateData, rejectedData) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: candidateData.isNotEmpty ? Colors.cyanAccent.withOpacity(0.1) : Colors.transparent,
                              border: Border.all(
                                color: candidateData.isNotEmpty ? Colors.cyanAccent.withOpacity(0.5) : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _viewIndex == 0 
                                ? (currentFolder?.title ?? 'Tu Biblioteca') 
                                : (_viewIndex == 1 ? 'Me gusta' : (_viewIndex == 2 ? 'Recientes' : (_viewIndex == 3 ? 'Descargas' : (_resolveFolder(library.playlists, _selectedPlaylistId ?? '')?.title ?? 'Playlist')))),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: candidateData.isNotEmpty ? Colors.cyanAccent : null,
                              ),
                            ),
                          );
                        },
                      ),
                      const Spacer(),
                      // Buttons - Show if in Grid (0) OR Playlist View (4)
                      if (_viewIndex == 0 || _viewIndex == 4) ...[
                        IconButton(
                          onPressed: () => showDialog(context: context, builder: (context) => SpotifyImportDialog(parentFolderId: _folderIds.isNotEmpty ? _folderIds.last : null)),
                          icon: const Icon(Icons.token_rounded, color: Color(0xFF1DB954)),
                          tooltip: 'Spotify',
                        ),
                        IconButton(
                          onPressed: () => showDialog(context: context, builder: (context) => YouTubeImportDialog(parentFolderId: _folderIds.isNotEmpty ? _folderIds.last : null)),
                          icon: const Icon(Icons.playlist_add_rounded, color: Colors.red),
                          tooltip: 'YouTube',
                        ),
                        if (_folderIds.isNotEmpty)
                          IconButton(
                            onPressed: () => setState(() {
                              _folderIds.removeLast();
                              _viewIndex = 0;
                              _selectedPlaylistId = null;
                            }),
                            icon: const Icon(Icons.drive_file_move_rtl_rounded, color: Color(0xFF7C4DFF)),
                            tooltip: 'Subir un nivel',
                          )
                        else
                          IconButton(
                            onPressed: () => _showCreatePlaylistDialog(context),
                            icon: const Icon(Icons.add_rounded, color: Color(0xFF7C4DFF)),
                            tooltip: 'Nueva Playlist',
                          ),
                      ],
                      if (_viewIndex != 0)
                        IconButton(
                          onPressed: () => setState(() { _viewIndex = 0; _selectedPlaylistId = null; }),
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _QuickActionChip(icon: Icons.favorite_rounded, label: 'Me gusta', color: const Color(0xFFFF4081), isSelected: _viewIndex == 1, 
                        onTap: () => setState(() {
                          _viewIndex = _viewIndex == 1 ? 0 : 1;
                          if (_viewIndex == 1) _selectedPlaylistId = null;
                        })),
                      const SizedBox(width: 10),
                      _QuickActionChip(icon: Icons.history_rounded, label: 'Recientes', color: const Color(0xFF7C4DFF), isSelected: _viewIndex == 2, 
                        onTap: () => setState(() {
                          _viewIndex = _viewIndex == 2 ? 0 : 2;
                          if (_viewIndex == 2) _selectedPlaylistId = null;
                        })),
                      const SizedBox(width: 10),
                      _QuickActionChip(icon: Icons.download_done_rounded, label: 'Descargas', color: scheme.primary, isSelected: _viewIndex == 3, 
                        onTap: () => setState(() {
                          _viewIndex = _viewIndex == 3 ? 0 : 3;
                          if (_viewIndex == 3) _selectedPlaylistId = null;
                        })),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                if (_viewIndex == 0) const SliverToBoxAdapter(child: SectionHeader(title: 'Tus Playlists')),
                if (_viewIndex == 0)
                  (currentFolder != null ? currentFolder.subPlaylists : library.playlists).isEmpty 
                    ? _buildEmptyPlaylists(theme, scheme)
                    : _buildPlaylistsGrid(currentFolder != null ? currentFolder.subPlaylists : library.playlists, theme, scheme),
                if (_viewIndex != 0)
                  _buildLibraryList(
                    _viewIndex == 1 ? library.likedSongs : 
                    (_viewIndex == 2 ? library.recentlyPlayed : 
                    (_viewIndex == 3 ? context.watch<DownloadProvider>().downloadedSongs : 
                    (_resolveFolder(library.playlists, _selectedPlaylistId ?? '')?.tracks ?? [])))
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsGrid(List<PlaylistEntity> playlists, ThemeData theme, ColorScheme scheme) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isDesktop ? 8 : 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final playlist = playlists[index];
            
            Widget buildCard({bool isHighlighted = false, bool isDragging = false}) {
              return FlowyPlaylistCard(
                playlist: playlist,
                isHighlighted: isHighlighted,
                onTap: () {
                  if (playlist.isFolder) {
                    setState(() {
                      _folderIds.add(playlist.id);
                      _viewIndex = 0;
                    });
                  } else {
                    setState(() { _selectedPlaylistId = playlist.id; _viewIndex = 4; });
                  }
                },
                onLongPress: () => _showPlaylistMenu(context, playlist, scheme),
              );
            }

            Widget draggable = Draggable<String>(
              data: playlist.id,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: Material(
                color: Colors.transparent,
                child: Opacity(
                  opacity: 0.8,
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: buildCard(),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: buildCard(isDragging: true),
              ),
              child: buildCard(),
            );

            return DragTarget<String>(
              onWillAccept: (data) => data != null && data != playlist.id,
              onAccept: (data) async {
                await context.read<LibraryProvider>().movePlaylistToFolder(data, playlist.id);
              },
              builder: (context, candidateData, rejectedData) {
                return Draggable<String>(
                  data: playlist.id,
                  dragAnchorStrategy: pointerDragAnchorStrategy,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Opacity(
                      opacity: 0.8,
                      child: SizedBox(
                        width: 160,
                        height: 160,
                        child: buildCard(),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: buildCard(isDragging: true),
                  ),
                  child: buildCard(isHighlighted: candidateData.isNotEmpty),
                );
              },
            );
          },
          childCount: playlists.length,
        ),
      ),
    );
  }

  Widget _buildEmptyPlaylists(ThemeData theme, ColorScheme scheme) {
    return SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
          child: Column(
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary.withOpacity(0.12)),
                child: Icon(Icons.library_music_rounded, size: 48, color: scheme.primary),
              ).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 1500.ms).then().scale(begin: const Offset(1.05, 1.05), end: const Offset(1, 1), duration: 1500.ms),
              const SizedBox(height: 20),
              Text('Tu biblioteca está vacía', style: theme.textTheme.titleMedium),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showCreatePlaylistDialog(context, parentFolderId: _folderIds.isNotEmpty ? _folderIds.last : null),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crear playlist'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF), 
                  foregroundColor: Colors.white, 
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryList(List<SongEntity> songs) {
    if (songs.isEmpty) return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: Text('No hay canciones aquí todavía', style: TextStyle(color: Colors.white30)))));
    return SliverList(delegate: SliverChildBuilderDelegate((context, index) {
      final song = songs[index];
      return SongTile(song: song, index: index, onTap: () {
        context.read<PlayerProvider>().playSong(song, queue: songs);
        context.read<LibraryProvider>().addToHistory(song);
        context.read<StatsProvider>().trackPlay(song);
      });
    }, childCount: songs.length));
  }


  void _showPlaylistMenu(BuildContext context, PlaylistEntity item, ColorScheme scheme) {
    showDialog(context: context, builder: (context) => SimpleDialog(
      backgroundColor: Color.lerp(scheme.surface, Colors.black, 0.9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: [
        SimpleDialogOption(onPressed: () { Navigator.pop(context); _showMoveToFolderDialog(context, item); }, child: const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Row(children: [Icon(Icons.drive_file_move_rounded, size: 20), SizedBox(width: 12), Text('Mover a carpeta')]))),
        SimpleDialogOption(onPressed: () { Navigator.pop(context); _showDeletePlaylistDialog(context, item, scheme); }, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Row(children: [Icon(Icons.delete_rounded, size: 20, color: scheme.error), SizedBox(width: 12), Text('Eliminar', style: TextStyle(color: scheme.error))]))),
      ],
    ));
  }

  void _showMoveToFolderDialog(BuildContext context, PlaylistEntity item) {
    final library = context.read<LibraryProvider>();
    List<PlaylistEntity> getAllFolders(List<PlaylistEntity> list) {
      List<PlaylistEntity> folders = [];
      for (var p in list) if (p.isFolder && p.id != item.id) { folders.add(p); folders.addAll(getAllFolders(p.subPlaylists)); }
      return folders;
    }
    final allFolders = getAllFolders(library.playlists);
    showDialog(context: context, builder: (context) => SimpleDialog(
      backgroundColor: const Color(0xFF161B2E), title: const Text('Mover a...'),
      children: [
        SimpleDialogOption(onPressed: () { library.movePlaylistToFolder(item.id, null); Navigator.pop(context); setState(() => _folderIds.clear()); }, child: const Row(children: [Icon(Icons.home_rounded, size: 20), SizedBox(width: 12), Text('Raíz de Biblioteca')])),
        const Divider(color: Colors.white10),
        ...allFolders.map((f) => SimpleDialogOption(onPressed: () { library.movePlaylistToFolder(item.id, f.id); Navigator.pop(context); setState(() => _folderIds.clear()); }, child: Row(children: [const Icon(Icons.folder_rounded, size: 20), const SizedBox(width: 12), Text(f.title)]))),
      ],
    ));
  }

  void _showDeletePlaylistDialog(BuildContext context, PlaylistEntity playlist, ColorScheme scheme) {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: Color.lerp(scheme.surface, Colors.black, 0.8),
      title: Text(playlist.isFolder ? 'Eliminar Carpeta' : 'Eliminar Playlist'),
      content: Text('¿Estás seguro que deseas eliminar "${playlist.title}"?${playlist.isFolder ? "\nSe eliminará todo su contenido." : ""}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () { context.read<LibraryProvider>().deletePlaylist(playlist.id); Navigator.pop(context); if (_folderIds.contains(playlist.id)) setState(() => _folderIds.clear()); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), child: const Text('Eliminar')),
      ],
    ));
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon; final String label; final Color color; final bool isSelected; final VoidCallback onTap;
  const _QuickActionChip({required this.icon, required this.label, required this.color, this.isSelected = false, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(onTap: onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isSelected ? [color, color.withOpacity(0.8)] : [color.withOpacity(0.3), color.withOpacity(0.15)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14), border: Border.all(color: isSelected ? Colors.white24 : color.withOpacity(0.3), width: 1),
        boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)] : [],
      ),
      child: Row(children: [Icon(icon, color: isSelected ? Colors.white : color, size: 20), const SizedBox(width: 8), Expanded(child: Text(label, style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis))]),
    )));
  }
}
