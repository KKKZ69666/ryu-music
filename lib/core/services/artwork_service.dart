import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class ArtworkService {
  ArtworkService._();
  static final ArtworkService instance = ArtworkService._();

  static const MethodChannel _channel = MethodChannel('com.ryu.music/media_store');

  final Map<String, Uint8List?> _memoryCache = {};
  final Map<String, Future<Uint8List?>> _inFlight = {};
  Directory? _cacheDir;

  String _cacheKey(int songId, int albumId) =>
      albumId > 0 ? 'album_$albumId' : 'song_$songId';

  Uint8List? getCachedBytes(int songId, int albumId) {
    final key = _cacheKey(songId, albumId);
    if (_memoryCache.containsKey(key)) return _memoryCache[key];
    return null;
  }

  Future<Uint8List?> getArtworkBytes(int songId, int albumId) {
    final key = _cacheKey(songId, albumId);
    if (_memoryCache.containsKey(key)) {
      return Future.value(_memoryCache[key]);
    }
    if (_inFlight.containsKey(key)) {
      return _inFlight[key]!;
    }

    final future = _fetchAndCache(key, songId, albumId);
    _inFlight[key] = future;
    return future;
  }

  Future<Uint8List?> _fetchAndCache(
    String key,
    int songId,
    int albumId,
  ) async {
    try {
      final dir = await _getCacheDir();
      final file = File('${dir.path}/$key.jpg');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          _memoryCache[key] = bytes;
          return bytes;
        }
      }

      final bytes = await _channel.invokeMethod<Uint8List>(
        'getArtwork',
        {'songId': songId, 'albumId': albumId},
      );

      _memoryCache[key] = bytes;
      if (bytes != null && bytes.isNotEmpty) {
        await file.writeAsBytes(bytes, flush: false);
      }
      return bytes;
    } catch (_) {
      _memoryCache[key] = null;
      return null;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Returns a file:// Uri for Android MediaSession / lock screen notifications.
  Future<Uri?> getArtworkFileUri(int songId, int albumId) async {
    final bytes = await getArtworkBytes(songId, albumId);
    if (bytes == null || bytes.isEmpty) return null;
    final dir = await _getCacheDir();
    final key = _cacheKey(songId, albumId);
    final file = File('${dir.path}/$key.jpg');
    if (!await file.exists()) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return file.uri;
  }

  /// Synchronously returns file:// Uri only if already persisted on disk.
  Uri? getExistingArtworkFileUriSync(int songId, int albumId) {
    final dir = _cacheDir;
    if (dir == null) return null;
    final key = _cacheKey(songId, albumId);
    final file = File('${dir.path}/$key.jpg');
    if (file.existsSync()) return file.uri;
    return null;
  }

  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final temp = await getTemporaryDirectory();
    final artDir = Directory('${temp.path}/ryu_art_cache');
    if (!await artDir.exists()) {
      await artDir.create(recursive: true);
    }
    _cacheDir = artDir;
    return artDir;
  }

  void clearMemoryCache() {
    _memoryCache.clear();
  }
}
