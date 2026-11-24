import 'package:flutter/material.dart';
import '../../core/models/album.dart';
import '../../core/models/artist.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import '../../core/ryu_scope.dart';
import '../../core/services/audius_service.dart';
import '../../core/theme/ryu_colors.dart';
import '../../shared/widgets/artwork_image.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/song_tile.dart';
import '../library/album_detail_screen.dart';
import '../library/artist_detail_screen.dart';
import '../library/playlist_detail_screen.dart';

enum _SearchFilter {
  all('All'),
  songs('Songs'),
  albums('Albums'),
  artists('Artists'),
  playlists('Playlists');

  const _SearchFilter(this.label);
  final String label;
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  _SearchFilter _filter = _SearchFilter.all;
  List<Song> _onlineSongs = const [];
  bool _isSearchingOnline = false;
  String? _onlineError;

  Future<void> _searchOnline(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() { _onlineSongs = const []; _onlineError = null; });
      return;
    }
    setState(() { _isSearchingOnline = true; _onlineError = null; });
    try {
      final songs = await AudiusService.instance.searchTracks(query);
      if (!mounted || _controller.text.trim() != query) return;
      setState(() => _onlineSongs = songs);
    } catch (e) {
      if (!mounted || _controller.text.trim() != query) return;
      setState(() { _onlineSongs = const []; _onlineError = 'Online search is temporarily unavailable.'; });
    } finally {
      if (mounted && _controller.text.trim() == query) {
        setState(() => _isSearchingOnline = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_query != _controller.text) {
        setState(() => _query = _controller.text);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scope = RyuScope.of(context);

    return ListenableBuilder(
      listenable: scope.library,
      builder: (context, _) {
        final library = scope.library;
        final q = _query.trim().toLowerCase();

        final matchedSongs = q.isEmpty
            ? const <Song>[]
            : library.songs
                .where(
                  (s) =>
                      s.title.toLowerCase().contains(q) ||
                      s.artist.toLowerCase().contains(q) ||
                      s.album.toLowerCase().contains(q),
                )
                .toList();

        final matchedAlbums = q.isEmpty
            ? const <Album>[]
            : library.albums
                .where(
                  (a) =>
                      a.name.toLowerCase().contains(q) ||
                      a.artist.toLowerCase().contains(q),
                )
                .toList();

        final matchedArtists = q.isEmpty
            ? const <Artist>[]
            : library.artists
                .where((a) => a.name.toLowerCase().contains(q))
                .toList();

        final matchedPlaylists = q.isEmpty
            ? const <RyuPlaylist>[]
            : library.playlists
                .where(
                  (p) =>
                      p.name.toLowerCase().contains(q) ||
                      p.description.toLowerCase().contains(q),
                )
                .toList();

        final hasAnyResults = _onlineSongs.isNotEmpty || matchedSongs.isNotEmpty ||
            matchedAlbums.isNotEmpty ||
            matchedArtists.isNotEmpty ||
            matchedPlaylists.isNotEmpty;

        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 28, 0, 165),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Search',
                  style: t.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (val) {
                    library.addRecentSearch(val);
                    _searchOnline(val);
                  },
                  decoration: InputDecoration(
                    hintText: 'Songs, artists, albums, playlists',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isNotEmpty
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Search online',
                                onPressed: () {
                                  library.addRecentSearch(_query);
                                  _searchOnline(_query);
                                },
                                icon: const Icon(Icons.travel_explore_rounded),
                              ),
                              IconButton(
                                onPressed: () {
                                  _controller.clear();
                                  setState(() { _query = ''; _onlineSongs = const []; _onlineError = null; });
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          )
                        : null,
                    filled: true,
                    fillColor: RyuColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              if (q.isEmpty) ...[
                if (library.recentSearches.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Searches',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        TextButton(
                          onPressed: library.clearRecentSearches,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final recent in library.recentSearches)
                          ActionChip(
                            label: Text(recent),
                            backgroundColor: RyuColors.surface,
                            onPressed: () {
                              _controller.text = recent;
                            },
                          ),
                      ],
                    ),
                  ),
                ] else
                  EmptyState(
                    icon: Icons.search_rounded,
                    message: library.songs.isEmpty
                        ? 'Scan your local library first to search across songs, artists, and albums.'
                        : 'Search across ${library.songs.length} local tracks, ${library.albums.length} albums, and ${library.artists.length} artists.',
                  ),
              ] else ...[
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Row(
                    children: [
                      for (final f in _SearchFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f.label),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                            selectedColor:
                                RyuColors.violet.withValues(alpha: 0.3),
                            backgroundColor: RyuColors.surface,
                          ),
                        ),
                    ],
                  ),
                ),

                if (_isSearchingOnline)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_onlineError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(_onlineError!, style: const TextStyle(color: RyuColors.textSecondary)),
                  ),
                if (_onlineSongs.isNotEmpty &&
                    (_filter == _SearchFilter.all || _filter == _SearchFilter.songs)) ...[
                  SectionHeader('Online tracks (${_onlineSongs.length})'),
                  for (final song in _onlineSongs)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 3),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: RyuColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.music_note_rounded),
                      ),
                      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${song.artist} • Audius', maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: RyuColors.textSecondary, fontSize: 12.5)),
                      trailing: const Icon(Icons.play_circle_fill_rounded),
                      onTap: () {
                        library.addRecentSearch(_query);
                        scope.audio.playSongs(_onlineSongs,
                            initialIndex: _onlineSongs.indexOf(song),
                            contextLabel: 'Audius • "$_query"');
                      },
                    ),
                ],

                if (!hasAnyResults && !_isSearchingOnline && _onlineError == null)
                  EmptyState(
                    icon: Icons.search_off_rounded,
                    message: 'No matches found for "$_query".',
                  )
                else ...[
                  if ((_filter == _SearchFilter.all ||
                          _filter == _SearchFilter.songs) &&
                      matchedSongs.isNotEmpty) ...[
                    SectionHeader('Songs (${matchedSongs.length})'),
                    for (int i = 0; i < matchedSongs.length; i++)
                      SongTile(
                        song: matchedSongs[i],
                        onTap: () {
                          library.addRecentSearch(_query);
                          scope.audio.playSongs(
                            matchedSongs,
                            initialIndex: i,
                            contextLabel: 'Search "$_query"',
                          );
                        },
                      ),
                  ],
                  if ((_filter == _SearchFilter.all ||
                          _filter == _SearchFilter.albums) &&
                      matchedAlbums.isNotEmpty) ...[
                    SectionHeader('Albums (${matchedAlbums.length})'),
                    for (final album in matchedAlbums)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        leading: ArtworkImage(
                          songId: album.coverSongId,
                          albumId: album.id,
                          size: 50,
                          borderRadius: 12,
                        ),
                        title: Text(
                          album.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${album.artist} • ${album.trackCount} tracks',
                          style: const TextStyle(
                            color: RyuColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                        onTap: () {
                          library.addRecentSearch(_query);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AlbumDetailScreen(album: album),
                            ),
                          );
                        },
                      ),
                  ],
                  if ((_filter == _SearchFilter.all ||
                          _filter == _SearchFilter.artists) &&
                      matchedArtists.isNotEmpty) ...[
                    SectionHeader('Artists (${matchedArtists.length})'),
                    for (final artist in matchedArtists)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        leading: ArtworkImage(
                          songId: artist.coverSongId,
                          albumId: artist.coverAlbumId,
                          size: 50,
                          borderRadius: 25,
                        ),
                        title: Text(
                          artist.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${artist.trackCount} tracks',
                          style: const TextStyle(
                            color: RyuColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                        onTap: () {
                          library.addRecentSearch(_query);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ArtistDetailScreen(artist: artist),
                            ),
                          );
                        },
                      ),
                  ],
                  if ((_filter == _SearchFilter.all ||
                          _filter == _SearchFilter.playlists) &&
                      matchedPlaylists.isNotEmpty) ...[
                    SectionHeader('Playlists (${matchedPlaylists.length})'),
                    for (final pl in matchedPlaylists)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: RyuColors.accent,
                          ),
                          child: const Icon(
                            Icons.queue_music_rounded,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          pl.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${pl.songIds.length} tracks',
                          style: const TextStyle(
                            color: RyuColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                        onTap: () {
                          library.addRecentSearch(_query);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  PlaylistDetailScreen(playlistId: pl.id),
                            ),
                          );
                        },
                      ),
                  ],
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
