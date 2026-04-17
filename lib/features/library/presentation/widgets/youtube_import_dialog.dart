import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/di/injection.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../domain/repositories/repositories.dart';
import '../providers/library_provider.dart';

class YouTubeImportDialog extends StatefulWidget {
  final String? parentFolderId;
  const YouTubeImportDialog({super.key, this.parentFolderId});

  @override
  State<YouTubeImportDialog> createState() => _YouTubeImportDialogState();
}

class _YouTubeImportDialogState extends State<YouTubeImportDialog> {
  final TextEditingController _urlController = TextEditingController();
  final MusicRepository _repository = sl<MusicRepository>();
  bool _isProcessing = false;
  String _status = '';
  double _progress = 0.0;

  String? _extractPlaylistId(String url) {
    if (url.isEmpty) return null;
    
    // If it looks like a direct ID (e.g. starting with PL, RD, etc.)
    final idRegex = RegExp(r'^(PL|RD|OL|UL|WL|LL|FL)[a-zA-Z0-9\-_]+$');
    if (idRegex.hasMatch(url)) return url;
    
    try {
      final uri = Uri.parse(url);
      final listId = uri.queryParameters['list'];
      final videoId = uri.queryParameters['v'];

      if (listId != null) {
        // For RD mixes, if there's a video ID, we append it as a hint: "LISTID|VIDEOID"
        if (listId.startsWith('RD') && videoId != null) {
          return '$listId|$videoId';
        }
        return listId;
      }

      // If no playlist ID but has video ID, we can generate a Mix ID automatically
      if (videoId != null && videoId.length == 11) {
        return 'RD$videoId|$videoId';
      }
    } catch (_) {}
    return null;
  }

  Future<void> _startImport() async {
    final url = _urlController.text.trim();
    final playlistId = _extractPlaylistId(url);

    if (playlistId == null) {
      setState(() => _status = 'URL no reconocida. Probá con una playlist o video.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'Analizando contenido de YouTube...';
      _progress = 0.3;
    });

    try {
      final result = await _repository.getPlaylist(playlistId);
      
      result.fold(
        (failure) {
          setState(() {
            _isProcessing = false;
            _status = 'Error: No se pudo encontrar la lista. Verificá que sea pública.';
          });
        },
        (playlist) async {
          setState(() {
            _status = 'Importando "${playlist.title}" (${playlist.tracks.length} temas)...';
            _progress = 0.9;
          });

          await context.read<LibraryProvider>().importPlaylist(playlist, parentFolderId: widget.parentFolderId);

          if (!mounted) return;
          setState(() {
            _status = '¡Listo! "${playlist.title}" se guardó en tu biblioteca.';
            _progress = 1.0;
            _isProcessing = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _status = 'Error inesperado: $e';
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: Color.lerp(scheme.surface, Colors.black, 0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.playlist_add_rounded, color: Colors.red, size: 28),
          const SizedBox(width: 8),
          const Expanded(child: Text('Importar de YouTube', style: TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pegá el enlace de tu Mix o Playlist de YouTube para agregarla a Flowy.',
            style: TextStyle(fontSize: 13, color: Colors.white60),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            enabled: !_isProcessing,
            decoration: InputDecoration(
              hintText: 'https://youtube.com/playlist?list=...',
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.link_rounded, size: 20, color: Colors.white30),
            ),
          ),
          const SizedBox(height: 16),
          if (_isProcessing || _status.isNotEmpty) ...[
            Text(_status, style: TextStyle(color: scheme.onSurface.withOpacity(0.7), fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 12),
          ],
          if (_isProcessing)
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              color: Colors.red,
              backgroundColor: Colors.white10,
              borderRadius: BorderRadius.circular(4),
            ),
        ],
      ),
      actions: [
        if (!_isProcessing)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: scheme.onSurface.withOpacity(0.5))),
          ),
        if (!_isProcessing && _progress < 1.0)
          ElevatedButton(
            onPressed: _startImport,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('Importar Ahora', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}
