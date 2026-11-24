import 'package:flutter/foundation.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/history_entry.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/local_music_scanner.dart';
import '../services/storage_service.dart';

enum SongSortOption {
  title('Title A–Z'),
  artist('Artist'),
  album('Album'),
  recentlyAdded('Recently Added');

  const SongSortOption(this.label);
  final String label;
}

class LibraryController extends ChangeNotifier {
  final StorageService _storage = StorageService.instance;
  final LocalMusicScanner _scanner = LocalMusicScanner.instance;

  List<Song> _songs = [];
  Map<int, Song> _songById = {};
  List<Album> _albums = [];
  List<Artist> _artists = [];

  Set<int> _favoriteIds = {};
  List<RyuPlaylist> _playlists = [];
  List<HistoryEntry> _history = [];
  Map<int, int> _playCounts = {};
  List<String> _recentSearches = [];

  bool _isScanning = false;
  String? _scanError;
  AudioPermissionStatus _permissionStatus = AudioPermissionStatus.denied;
  SongSortOption _sortOption = SongSortOption.title;

  List<Song> get songs => _songs;
  List<Album> get albums => _albums;
  List<Artist> get artists => _artists;
  Set<int> get favoriteIds => _favoriteIds;
  List<RyuPlaylist> get playlists => _playlists;
  List<HistoryEntry> get history => _history;
  Map<int, int> get playCounts => _playCounts;
  List<String> get recentSearches => _recentSearches;
  bool get isScanning => _isScanning;
  String? get scanError => _scanError;
  AudioPermissionStatus get permissionStatus => _permissionStatus;
  SongSortOption get sortOption => _sortOption;

  Song? songById(int id) => _songById[id];

  bool isFavorite(int songId) => _favoriteIds.contains(songId);

  List<Song> get favoriteSongs => _favoriteIds
      .map((id) => _songById[id])
      .whereType<Song>()
      .toList();

  /// Unique recently played songs ordered by most recent play.
  List<Song> get recentlyPlayedSongs {
    final seen = <int>{};
    final result = <Song>[];
    for (final entry in _history) {
      if (seen.add(entry.songId)) {
        final song = _songById[entry.songId];
        if (song != null) result.add(song);
      }
    }
    return result;
  }

  /// Most played songs sorted by play count descending.
  List<Song> get mostPlayedSongs {
    final entries = _playCounts.entries
        .where((e) => e.value > 0 && _songById.containsKey(e.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => _songById[e.key]!).toList();
  }

  /// Recently added songs from local device storage.
  List<Song> get recentlyAddedSongs {
    final copy = List<Song>.from(_songs)
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return copy;
  }

  /// Smart local recommendations derived strictly from the user's real library.
  List<Song> get recommendedSongs {
    if (_songs.isEmpty) return const [];
    final recentIds = recentlyPlayedSongs.take(8).map((s) => s.id).toSet();

    // Prioritize songs from top-played artists that haven't been played very recently
    final artistScore = <String, int>{};
    for (final entry in _playCounts.entries) {
      final song = _songById[entry.key];
      if (song != null) {
        artistScore[song.artist] = (artistScore[song.artist] ?? 0) + entry.value;
      }
    }

    final candidates = List<Song>.from(_songs);
    candidates.sort((a, b) {
      final aRecentPenalty = recentIds.contains(a.id) ? -1000 : 0;
      final bRecentPenalty = recentIds.contains(b.id) ? -1000 : 0;
      final aScore = (artistScore[a.artist] ?? 0) + aRecentPenalty;
      final bScore = (artistScore[b.artist] ?? 0) + bRecentPenalty;
      if (bScore != aScore) return bScore.compareTo(aScore);
      return b.dateAdded.compareTo(a.dateAdded);
    });

    return candidates.take(12).toList();
  }

  List<Album> get featuredAlbums {
    if (_albums.isEmpty) return const [];
    final sorted = List<Album>.from(_albums)
      ..sort((a, b) => b.trackCount.compareTo(a.trackCount));
    return sorted.take(10).toList();
  }

  Future<void> initialize() async {
    _favoriteIds = _storage.loadFavorites();
    _playlists = _storage.loadPlaylists();
    _history = _storage.loadHistory();
    _playCounts = _storage.loadPlayCounts();
    _recentSearches = _storage.loadRecentSearches();
    notifyListeners();

    await scanLibrary(requestPermission: true);
  }

  Future<void> scanLibrary({bool requestPermission = true}) async {
    _isScanning = true;
    _scanError = null;
    notifyListeners();

    try {
      final status = await _scanner.checkAndRequestPermission(
        requestIfNeeded: requestPermission,
      );
      _permissionStatus = status;

      if (status != AudioPermissionStatus.granted) {
        _isScanning = false;
        notifyListeners();
        return;
      }

      final scanned = await _scanner.scanSongs();
      _songs = scanned;
      _songById = {for (final s in scanned) s.id: s};
      _applySort();
      _rebuildAlbumsAndArtists();
    } catch (e) {
      _scanError = 'Unable to scan local music: $e';
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  void setSortOption(SongSortOption option) {
    if (_sortOption == option) return;
    _sortOption = option;
    _applySort();
    notifyListeners();
  }

  void _applySort() {
    switch (_sortOption) {
      case SongSortOption.title:
        _songs.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case SongSortOption.artist:
        _songs.sort((a, b) {
          final cmp = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
          return cmp != 0
              ? cmp
              : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      case SongSortOption.album:
        _songs.sort((a, b) {
          final cmp = a.album.toLowerCase().compareTo(b.album.toLowerCase());
          return cmp != 0 ? cmp : a.trackNumber.compareTo(b.trackNumber);
        });
      case SongSortOption.recentlyAdded:
        _songs.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    }
  }

  void _rebuildAlbumsAndArtists() {
    final albumGroups = <int, List<Song>>{};
    for (final song in _songs) {
      albumGroups.putIfAbsent(song.albumId, () => []).add(song);
    }

    final builtAlbums = <Album>[];
    albumGroups.forEach((albumId, albumSongs) {
      final sortedSongs = List<Song>.from(albumSongs)
        ..sort((a, b) {
          if (a.trackNumber > 0 && b.trackNumber > 0) {
            return a.trackNumber.compareTo(b.trackNumber);
          }
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      builtAlbums.add(
        Album(
          id: albumId,
          name: sortedSongs.first.album,
          artist: sortedSongs.first.artist,
          songs: sortedSongs,
        ),
      );
    });
    builtAlbums.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    _albums = builtAlbums;

    final artistSongs = <String, List<Song>>{};
    for (final song in _songs) {
      artistSongs.putIfAbsent(song.artist, () => []).add(song);
    }

    final builtArtists = <Artist>[];
    artistSongs.forEach((artistName, tracks) {
      final artistAlbums = builtAlbums
          .where((al) => al.songs.any((s) => s.artist == artistName))
          .toList();
      builtArtists.add(
        Artist(
          name: artistName,
          songs: tracks,
          albums: artistAlbums,
        ),
      );
    });
    builtArtists.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    _artists = builtArtists;
  }

  // Favorites
  Future<void> toggleFavorite(int songId) async {
    if (_favoriteIds.contains(songId)) {
      _favoriteIds.remove(songId);
    } else {
      _favoriteIds.add(songId);
    }
    notifyListeners();
    await _storage.saveFavorites(_favoriteIds);
  }

  // Listening History & Play Counts
  Future<void> recordSongPlay(Song song) async {
    _history.insert(
      0,
      HistoryEntry(songId: song.id, playedAt: DateTime.now()),
    );
    if (_history.length > 200) {
      _history = _history.sublist(0, 200);
    }
    _playCounts[song.id] = (_playCounts[song.id] ?? 0) + 1;
    notifyListeners();
    await _storage.saveHistory(_history);
    await _storage.savePlayCounts(_playCounts);
  }

  Future<void> clearHistory() async {
    _history.clear();
    notifyListeners();
    await _storage.saveHistory(_history);
  }

  // Playlists CRUD
  Future<RyuPlaylist> createPlaylist(
    String name, {
    String description = '',
    List<int> initialSongIds = const [],
  }) async {
    final now = DateTime.now();
    final playlist = RyuPlaylist(
      id: 'pl_${now.microsecondsSinceEpoch}',
      name: name.trim(),
      description: description.trim(),
      songIds: List<int>.from(initialSongIds),
      createdAt: now,
      updatedAt: now,
    );
    _playlists.insert(0, playlist);
    notifyListeners();
    await _storage.savePlaylists(_playlists);
    return playlist;
  }

  Future<void> renamePlaylist(
    String playlistId,
    String newName, {
    String? newDescription,
  }) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return;
    _playlists[idx] = _playlists[idx].copyWith(
      name: newName.trim(),
      description: newDescription?.trim(),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _storage.savePlaylists(_playlists);
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
    await _storage.savePlaylists(_playlists);
  }

  Future<void> addSongToPlaylist(String playlistId, int songId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return;
    final current = List<int>.from(_playlists[idx].songIds);
    if (!current.contains(songId)) {
      current.add(songId);
      _playlists[idx] = _playlists[idx].copyWith(
        songIds: current,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      await _storage.savePlaylists(_playlists);
    }
  }

  Future<void> addSongsToPlaylist(String playlistId, List<int> songIds) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return;
    final current = List<int>.from(_playlists[idx].songIds);
    bool changed = false;
    for (final id in songIds) {
      if (!current.contains(id)) {
        current.add(id);
        changed = true;
      }
    }
    if (changed) {
      _playlists[idx] = _playlists[idx].copyWith(
        songIds: current,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      await _storage.savePlaylists(_playlists);
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, int songId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return;
    final current = List<int>.from(_playlists[idx].songIds)..remove(songId);
    _playlists[idx] = _playlists[idx].copyWith(
      songIds: current,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _storage.savePlaylists(_playlists);
  }

  Future<void> reorderPlaylistSongs(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return;
    final current = List<int>.from(_playlists[idx].songIds);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    _playlists[idx] = _playlists[idx].copyWith(
      songIds: current,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _storage.savePlaylists(_playlists);
  }

  List<Song> resolvePlaylistSongs(RyuPlaylist playlist) {
    return playlist.songIds
        .map((id) => _songById[id])
        .whereType<Song>()
        .toList();
  }

  // Recent Searches
  Future<void> addRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _recentSearches.removeWhere(
      (q) => q.toLowerCase() == trimmed.toLowerCase(),
    );
    _recentSearches.insert(0, trimmed);
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.sublist(0, 10);
    }
    notifyListeners();
    await _storage.saveRecentSearches(_recentSearches);
  }

  Future<void> clearRecentSearches() async {
    _recentSearches.clear();
    notifyListeners();
    await _storage.saveRecentSearches(_recentSearches);
  }
}
