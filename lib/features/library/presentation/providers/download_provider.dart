
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../domain/entities/entities.dart';

class DownloadProvider extends ChangeNotifier {
  final Dio _dio = Dio();
  final Set<String> _downloadedIds = {};
  final Map<String, SongEntity> _downloadedMetadata = {};
  final Set<String> _fetchingIds = {};
  final Map<String, double?> _progress = {};
  final Map<String, CancelToken> _cancelTokens = {};
  
  DownloadProvider() {
    _loadDownloadedList();
  }

  Set<String> get downloadedIds => _downloadedIds;
  List<SongEntity> get downloadedSongs => _downloadedMetadata.values.toList();
  double? getProgress(String id) => _progress[id];
  bool isDownloaded(String id) => _downloadedIds.contains(id);
  bool isDownloading(String id) => _progress.containsKey(id);
  bool isFetching(String id) => _fetchingIds.contains(id);

  void setFetching(String id, bool active) {
    if (active) {
      _fetchingIds.add(id);
    } else {
      _fetchingIds.remove(id);
    }
    notifyListeners();
  }

  Future<void> _loadDownloadedList() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('downloaded_songs') ?? [];
    final metaJson = prefs.getString('downloaded_metadata_v2');
    
    _downloadedIds.addAll(list);
    
    if (metaJson != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(metaJson);
        decoded.forEach((key, value) {
          final m = Map<String, dynamic>.from(value);
          _downloadedMetadata[key] = SongEntity(
            id: m['id'] ?? key,
            title: m['title'] ?? '',
            artist: m['artist'] ?? '',
            thumbnailUrl: m['thumb'],
            duration: Duration(seconds: m['dur'] ?? 0),
          );
        });
      } catch (e) {
        debugPrint('[DownloadProvider] Error decoding metadata: $e');
      }
    }

    // Verify files still exist
    final dir = await getApplicationDocumentsDirectory();
    final toRemove = <String>[];
    for (final id in _downloadedIds) {
      final file = File('${dir.path}/downloads/$id.mp3');
      if (!await file.exists() || await file.length() == 0) {
        toRemove.add(id);
      }
    }
    
    if (toRemove.isNotEmpty) {
      _downloadedIds.removeAll(toRemove);
      for (final id in toRemove) {
        _downloadedMetadata.remove(id);
      }
      await _saveDownloadedList();
    }
    
    notifyListeners();
  }

  Future<void> _saveDownloadedList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('downloaded_songs', _downloadedIds.toList());
    
    final Map<String, dynamic> metaMap = {};
    _downloadedMetadata.forEach((key, s) {
      metaMap[key] = {
        'id': s.id,
        'title': s.title,
        'artist': s.artist,
        'thumb': s.thumbnailUrl,
        'dur': s.duration.inSeconds,
      };
    });
    await prefs.setString('downloaded_metadata_v2', json.encode(metaMap));
  }

  Future<String> getLocalPath(String id) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/downloads/$id.mp3';
  }

  Future<bool> downloadSong(SongEntity song, String streamUrl) async {
    if (isDownloaded(song.id) || isDownloading(song.id)) return false;

    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    final savePath = '${downloadDir.path}/${song.id}.mp3';
    
    final cancelToken = CancelToken();
    _cancelTokens[song.id] = cancelToken;

    try {
      _progress[song.id] = null; // Indeterminate at start
      notifyListeners();

      await _dio.download(
        streamUrl,
        savePath,
        cancelToken: cancelToken,
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _progress[song.id] = received / total;
            notifyListeners();
          } else {
            // Keep indeterminate
            if (_progress[song.id] != null) {
              _progress[song.id] = null;
              notifyListeners();
            }
          }
        },
      );

      // Verify file integrity
      final file = File(savePath);
      if (await file.exists() && await file.length() > 0) {
        _downloadedIds.add(song.id);
        _downloadedMetadata[song.id] = song;
        await _saveDownloadedList();
        return true;
      } else {
        throw Exception('File saved but is empty or missing');
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        debugPrint('[DownloadProvider] Download cancelled: ${song.title}');
        final file = File(savePath);
        if (await file.exists()) await file.delete();
      } else {
        debugPrint('[DownloadProvider] Error downloading ${song.title}: $e');
        final file = File(savePath);
        if (await file.exists()) await file.delete();
      }
      return false;
    } finally {
      _cancelTokens.remove(song.id);
      _progress.remove(song.id);
      notifyListeners();
    }
  }

  void cancelDownload(String id) {
    _cancelTokens[id]?.cancel();
  }

  Future<void> deleteDownload(String id) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/downloads/$id.mp3');
    if (await file.exists()) {
      await file.delete();
    }
    _downloadedIds.remove(id);
    await _saveDownloadedList();
    notifyListeners();
  }
}
