import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_entry.dart';
import '../models/playlist.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _kFavorites = 'ryu_favorites_v1';
  static const _kPlaylists = 'ryu_playlists_v1';
  static const _kHistory = 'ryu_history_v1';
  static const _kPlayCounts = 'ryu_play_counts_v1';
  static const _kShuffle = 'ryu_shuffle_v1';
  static const _kRepeat = 'ryu_repeat_v1';
  static const _kRecentSearches = 'ryu_recent_searches_v1';
  static const _kLyricsPrefix = 'ryu_lyrics_song_';

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // Favorites
  Set<int> loadFavorites() {
    final raw = _prefs.getStringList(_kFavorites) ?? const <String>[];
    return raw.map((e) => int.tryParse(e) ?? -1).where((id) => id >= 0).toSet();
  }

  Future<void> saveFavorites(Set<int> ids) async {
    await _prefs.setStringList(
      _kFavorites,
      ids.map((e) => e.toString()).toList(),
    );
  }

  // Playlists
  List<RyuPlaylist> loadPlaylists() {
    final raw = _prefs.getString(_kPlaylists);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => RyuPlaylist.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePlaylists(List<RyuPlaylist> playlists) async {
    final encoded = jsonEncode(playlists.map((p) => p.toJson()).toList());
    await _prefs.setString(_kPlaylists, encoded);
  }

  // Listening History
  List<HistoryEntry> loadHistory() {
    final raw = _prefs.getString(_kHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<HistoryEntry> entries) async {
    final capped = entries.take(200).toList();
    final encoded = jsonEncode(capped.map((e) => e.toJson()).toList());
    await _prefs.setString(_kHistory, encoded);
  }

  // Play Counts
  Map<int, int> loadPlayCounts() {
    final raw = _prefs.getString(_kPlayCounts);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final map = <int, int>{};
      decoded.forEach((key, value) {
        final id = int.tryParse(key);
        if (id != null && value is num) {
          map[id] = value.toInt();
        }
      });
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<void> savePlayCounts(Map<int, int> counts) async {
    final encoded = jsonEncode(
      counts.map((key, value) => MapEntry(key.toString(), value)),
    );
    await _prefs.setString(_kPlayCounts, encoded);
  }

  // Playback Modes
  bool loadShuffle() => _prefs.getBool(_kShuffle) ?? false;
  Future<void> saveShuffle(bool value) => _prefs.setBool(_kShuffle, value);

  int loadRepeatModeIndex() => _prefs.getInt(_kRepeat) ?? 0;
  Future<void> saveRepeatModeIndex(int index) =>
      _prefs.setInt(_kRepeat, index);

  // Recent Searches
  List<String> loadRecentSearches() =>
      _prefs.getStringList(_kRecentSearches) ?? const [];

  Future<void> saveRecentSearches(List<String> queries) =>
      _prefs.setStringList(_kRecentSearches, queries.take(12).toList());

  // Cached / User Lyrics per Song ID
  Map<String, String>? loadSongLyrics(int songId) {
    final raw = _prefs.getString('$_kLyricsPrefix$songId');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        'rawText': decoded['rawText'] as String? ?? '',
        'source': decoded['source'] as String? ?? 'manualInput',
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSongLyrics({
    required int songId,
    required String rawText,
    required String sourceName,
  }) async {
    await _prefs.setString(
      '$_kLyricsPrefix$songId',
      jsonEncode({
        'rawText': rawText,
        'source': sourceName,
      }),
    );
  }

  Future<void> clearSongLyrics(int songId) async {
    await _prefs.remove('$_kLyricsPrefix$songId');
  }
}
