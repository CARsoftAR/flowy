import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/di/injection.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../domain/repositories/repositories.dart';
import '../../data/services/spotify_importer_service.dart';
import '../providers/library_provider.dart';

class SpotifyImportDialog extends StatefulWidget {
  const SpotifyImportDialog({super.key});

  @override
  State<SpotifyImportDialog> createState() => _SpotifyImportDialogState();
}

class _SpotifyImportDialogState extends State<SpotifyImportDialog> {
  final TextEditingController _urlController = TextEditingController();
  final SpotifyImporterService _importer = SpotifyImporterService(sl<MusicRepository>());
  bool _isProcessing = false;
  String _status = '';
  int _totalTracks = 0;
  int _processedTracks = 0;
  int _foundTracks = 0;
  double _progress = 0.0;

  Future<void> _startImport() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.contains('spotify.com/playlist/')) {
      setState(() => _status = 'URL inválida. Pegá el enlace de una playlist de Spotify.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'Analizando playlist en Spotify...';
    });

    try {
      final info = await _importer.fetchPlaylistData(url);
      if (info == null) {
        setState(() {
          _isProcessing = false;
          _status = 'Error al leer la playlist. Verificá el enlace o tu conexión.';
        });
        return;
      }

      setState(() {
        _totalTracks = info.tracks.length;
        _status = 'Playlist leída: "${info.title}" ($_totalTracks canciones). Buscando...';
      });

      // Crear la playlist vacía local
      await context.read<LibraryProvider>().createPlaylist(info.title, description: 'Importada desde Spotify');
      final newPlaylistId = context.read<LibraryProvider>().playlists.last.id;
      final library = context.read<LibraryProvider>();

      await for (final songEntity in _importer.searchAndProcessTracks(info.tracks)) {
        if (!mounted) return;
        _processedTracks++;
        _progress = _processedTracks / _totalTracks;
        if (songEntity != null) {
          _foundTracks++;
          await library.addSongToPlaylist(newPlaylistId, songEntity);
        }
        setState(() {
          _status = 'Procesando: $_processedTracks/$_totalTracks. Encontradas: $_foundTracks...';
        });
      }

      setState(() {
        _status = '¡Importación finalizada! $_foundTracks canciones agregadas a "${info.title}".';
        _isProcessing = false;
      });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _status = 'Hubo un error inesperado al importar: $e';
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
      backgroundColor: Color.lerp(scheme.surface, Colors.black, 0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.token_rounded, color: Color(0xFF1DB954), size: 28),
          const SizedBox(width: 8),
          const Expanded(child: Text('Importar desde Spotify', style: TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _urlController,
            enabled: !_isProcessing,
            decoration: InputDecoration(
              hintText: 'https://open.spotify.com/playlist/...',
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
              color: const Color(0xFF1DB954),
              backgroundColor: Colors.white10,
              borderRadius: BorderRadius.circular(4),
            ),
        ],
      ),
      actions: [
        if (!_isProcessing)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: TextStyle(color: scheme.primary.withOpacity(0.7))),
          ),
        if (!_isProcessing && _progress < 1.0)
          ElevatedButton(
            onPressed: _startImport,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.black,
              shape: const StadiumBorder(),
            ),
            child: const Text('Comenzar Importación', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}
