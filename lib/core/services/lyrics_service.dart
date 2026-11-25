import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/lyric_line.dart';
import '../models/song.dart';
import '../utils/lrc_parser.dart';
import 'storage_service.dart';

class LyricsService {
  LyricsService._();
  static final LyricsService instance = LyricsService._();

  static const MethodChannel _channel = MethodChannel('com.ryu.music/media_store');

  /// Loads lyrics in priority order:
  /// 1. User-saved / cached lyrics in local storage
  /// 2. Sidecar .lrc/.txt file next to audio file on Android storage
  /// 3. Embedded ID3v2 USLT lyrics tag inside the audio file
  Future<LyricsDocument?> loadLyricsForSong(Song song) async {
    final stored = StorageService.instance.loadSongLyrics(song.id);
    if (stored != null && (stored['rawText'] ?? '').trim().isNotEmpty) {
      final raw = stored['rawText']!;
      final sourceName = stored['source'] ?? 'manualInput';
      final source = LyricsSource.values.firstWhere(
        (e) => e.name == sourceName,
        orElse: () => LyricsSource.manualInput,
      );
      final lines = LrcParser.parse(raw);
      if (lines.isNotEmpty) {
        return LyricsDocument(lines: lines, source: source, rawText: raw);
      }
    }

    try {
      final localRaw = await _channel.invokeMethod<String>(
        'getLocalLyrics',
        {'filePath': song.filePath},
      );
      if (localRaw != null && localRaw.trim().isNotEmpty) {
        final lines = LrcParser.parse(localRaw);
        if (lines.isNotEmpty) {
          final isSidecar = _looksLikeLrc(localRaw);
          return LyricsDocument(
            lines: lines,
            source: isSidecar ? LyricsSource.sidecarLrc : LyricsSource.embeddedTag,
            rawText: localRaw,
          );
        }
      }
    } catch (_) {
      // Ignore native channel error and return null
    }

    return null;
  }

  bool _looksLikeLrc(String text) =>
      RegExp(r'\[\d{1,3}:\d{2}').hasMatch(text);

  /// Opens Android's system file picker to import a legal .lrc or .txt lyrics file.
  Future<LyricsDocument?> importLrcFromDevice(Song song) async {
    final content = await _channel.invokeMethod<String>('pickLrcFile');
    if (content == null || content.trim().isEmpty) return null;
    return saveCustomLyrics(
      song: song,
      rawText: content,
      source: LyricsSource.importedFile,
    );
  }

  /// Saves pasted or edited lyrics locally for [song].
  Future<LyricsDocument?> saveCustomLyrics({
    required Song song,
    required String rawText,
    LyricsSource source = LyricsSource.manualInput,
  }) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return null;
    final lines = LrcParser.parse(trimmed);
    if (lines.isEmpty) return null;

    await StorageService.instance.saveSongLyrics(
      songId: song.id,
      rawText: trimmed,
      sourceName: source.name,
    );

    return LyricsDocument(
      lines: lines,
      source: source,
      rawText: trimmed,
    );
  }

  /// User-initiated lookup against LRCLIB (open-source legal lyrics database).
  Future<LyricsDocument?> fetchFromLrclib(Song song) async {
    final cleanTitle = _cleanMetadata(song.title);
    final cleanArtist =
        song.artist == 'Unknown Artist' ? '' : _cleanMetadata(song.artist);
    final cleanAlbum =
        song.album == 'Unknown Album' ? '' : _cleanMetadata(song.album);

    final queryParams = <String, String>{
      'track_name': cleanTitle,
      if (cleanArtist.isNotEmpty) 'artist_name': cleanArtist,
      if (cleanAlbum.isNotEmpty) 'album_name': cleanAlbum,
      if (song.durationMs > 0)
        'duration': (song.durationMs / 1000).round().toString(),
    };

    final uri = Uri.https('lrclib.net', '/api/get', queryParams);
    final response = await http.get(
      uri,
      headers: const {
        'User-Agent': 'RYU-Android-Music-Player/1.0.0',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final synced = data['syncedLyrics'] as String?;
      final plain = data['plainLyrics'] as String?;
      final chosen = (synced != null && synced.trim().isNotEmpty)
          ? synced
          : (plain != null && plain.trim().isNotEmpty ? plain : null);

      if (chosen != null) {
        return saveCustomLyrics(
          song: song,
          rawText: chosen,
          source: LyricsSource.lrclibOnline,
        );
      }
    }

    // Fallback search endpoint if exact match returns 404
    final searchUri = Uri.https('lrclib.net', '/api/search', {
      'track_name': cleanTitle,
      if (cleanArtist.isNotEmpty) 'artist_name': cleanArtist,
    });
    final searchRes = await http.get(
      searchUri,
      headers: const {
        'User-Agent': 'RYU-Android-Music-Player/1.0.0',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (searchRes.statusCode == 200) {
      final list = jsonDecode(searchRes.body) as List<dynamic>;
      for (final item in list.whereType<Map<String, dynamic>>()) {
        final synced = item['syncedLyrics'] as String?;
        final plain = item['plainLyrics'] as String?;
        final chosen = (synced != null && synced.trim().isNotEmpty)
            ? synced
            : (plain != null && plain.trim().isNotEmpty ? plain : null);
        if (chosen != null) {
          return saveCustomLyrics(
            song: song,
            rawText: chosen,
            source: LyricsSource.lrclibOnline,
          );
        }
      }
    }

    return null;
  }

  Future<void> clearSavedLyrics(int songId) async {
    await StorageService.instance.clearSongLyrics(songId);
  }

  String _cleanMetadata(String value) {
    return value
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .replaceAll(RegExp(r'\s*\[[^\]]*\]'), '')
        .trim();
  }
}
