import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/controllers/library_controller.dart';
import '../../core/ryu_scope.dart';
import '../../core/services/local_music_scanner.dart';
import '../../core/theme/ryu_colors.dart';
import '../../shared/widgets/artwork_image.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/song_tile.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';
import 'history_screen.dart';
import 'playlist_detail_screen.dart';

enum _LibraryCategory {
  songs('Songs'),
  albums('Albums'),
  artists('Artists'),
  playlists('Playlists');

  const _LibraryCategory(this.label);
  final String label;
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  _LibraryCategory _category = _LibraryCategory.songs;

  Future<void> _showCreatePlaylistDialog(
    BuildContext context,
    LibraryController library,
  ) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RyuColors.surface,
        title: const Text('New Playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Playlist name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                hintText: 'Description (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true && nameCtrl.text.trim().isNotEmpty) {
      await library.createPlaylist(
        nameCtrl.text,
        description: descCtrl.text,
      );
    }
    nameCtrl.dispose();
    descCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scope = RyuScope.of(context);

    return ListenableBuilder(
      listenable: scope.library,
      builder: (context, _) {
        final library = scope.library;

        return SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: RyuColors.violet,
            backgroundColor: RyuColors.surface,
            onRefresh: () => library.scanLibrary(requestPermission: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 28, 0, 165),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Library',
                          style: t.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Rescan local music',
                        onPressed: library.isScanning
                            ? null
                            : () => library.scanLibrary(requestPermission: true),
                        icon: library.isScanning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: RyuColors.violet,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                      ),
                      IconButton(
                        tooltip: 'Create playlist',
                        onPressed: () =>
                            _showCreatePlaylistDialog(context, library),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                    ],
                  ),
                ),

                // Quick shortcuts: Favorites & Listening History
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: _QuickAccessCard(
                          icon: Icons.favorite_rounded,
                          title: 'Favorites',
                          subtitle: '${library.favoriteSongs.length} tracks',
                          accent: RyuColors.violet,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PlaylistDetailScreen(
                                smartKind: SmartPlaylistKind.favorites,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickAccessCard(
                          icon: Icons.history_rounded,
                          title: 'History',
                          subtitle: '${library.history.length} plays',
                          accent: RyuColors.blue,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HistoryScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Category Segmented Selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Row(
                    children: [
                      for (final cat in _LibraryCategory.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat.label),
                            selected: _category == cat,
                            onSelected: (_) =>
                                setState(() => _category = cat),
                            selectedColor:
                                RyuColors.violet.withValues(alpha: 0.3),
                            backgroundColor: RyuColors.surface,
                            side: BorderSide(
                              color: _category == cat
                                  ? RyuColors.violet
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _category == cat
                                  ? Colors.white
                                  : RyuColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                if (library.permissionStatus != AudioPermissionStatus.granted)
                  _buildPermissionCard(library)
                else if (library.songs.isEmpty && !library.isScanning)
                  const EmptyState(
                    icon: Icons.music_off_rounded,
                    message:
                        'No audio files found on this device. Add MP3, FLAC, M4A, or WAV files to your Music folder and pull down to rescan.',
                  )
                else
                  switch (_category) {
                    _LibraryCategory.songs => _buildSongsTab(context, scope),
                    _LibraryCategory.albums => _buildAlbumsTab(context, library),
                    _LibraryCategory.artists =>
                      _buildArtistsTab(context, library),
                    _LibraryCategory.playlists =>
                      _buildPlaylistsTab(context, library),
                  },
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPermissionCard(LibraryController library) {
    final permDenied =
        library.permissionStatus == AudioPermissionStatus.permanentlyDenied;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: RyuColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.folder_special_rounded, color: RyuColors.violet),
          const SizedBox(height: 12),
          const Text(
            'Audio Storage Permission Required',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'RYU needs permission to read local audio files on your Android device.',
            style: TextStyle(color: RyuColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () {
              if (permDenied) {
                openAppSettings();
              } else {
                library.scanLibrary(requestPermission: true);
              }
            },
            child: Text(permDenied ? 'Open App Settings' : 'Grant Permission'),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsTab(BuildContext context, RyuScope scope) {
    final songs = scope.library.songs;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Row(
            children: [
              Text(
                '${songs.length} songs',
                style: const TextStyle(
                  color: RyuColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              PopupMenuButton<SongSortOption>(
                color: RyuColors.surface,
                onSelected: scope.library.setSortOption,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sort_rounded,
                      size: 18,
                      color: RyuColors.violet,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      scope.library.sortOption.label,
                      style: const TextStyle(
                        color: RyuColors.violet,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                itemBuilder: (_) => [
                  for (final opt in SongSortOption.values)
                    PopupMenuItem(value: opt, child: Text(opt.label)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => scope.audio.playSongs(
                    songs,
                    contextLabel: 'All Songs',
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play All'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => scope.audio.playSongs(
                    songs,
                    contextLabel: 'All Songs',
                    forceShuffle: true,
                  ),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Shuffle'),
                ),
              ),
            ],
          ),
        ),
        for (int i = 0; i < songs.length; i++)
          SongTile(
            song: songs[i],
            onTap: () => scope.audio.playSongs(
              songs,
              initialIndex: i,
              contextLabel: 'All Songs',
            ),
          ),
      ],
    );
  }

  Widget _buildAlbumsTab(BuildContext context, LibraryController library) {
    final albums = library.albums;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AlbumDetailScreen(album: album),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (_, constraints) => ArtworkImage(
                    songId: album.coverSongId,
                    albumId: album.id,
                    size: constraints.maxWidth,
                    borderRadius: 20,
                    iconSize: 40,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                '${album.artist} • ${album.trackCount} tracks',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RyuColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtistsTab(BuildContext context, LibraryController library) {
    final artists = library.artists;
    return Column(
      children: [
        for (final artist in artists)
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${artist.albumCount} albums • ${artist.trackCount} tracks',
              style: const TextStyle(
                color: RyuColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: RyuColors.textSecondary,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ArtistDetailScreen(artist: artist),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaylistsTab(BuildContext context, LibraryController library) {
    final customPlaylists = library.playlists;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showCreatePlaylistDialog(context, library),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create New Playlist'),
            ),
          ),
        ),
        _PlaylistTile(
          icon: Icons.favorite_rounded,
          title: 'Favorites',
          subtitle: '${library.favoriteSongs.length} tracks',
          gradientColors: const [RyuColors.violet, RyuColors.indigo],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PlaylistDetailScreen(
                smartKind: SmartPlaylistKind.favorites,
              ),
            ),
          ),
        ),
        _PlaylistTile(
          icon: Icons.trending_up_rounded,
          title: 'Most Played',
          subtitle: '${library.mostPlayedSongs.length} tracks',
          gradientColors: const [RyuColors.indigo, RyuColors.blue],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PlaylistDetailScreen(
                smartKind: SmartPlaylistKind.mostPlayed,
              ),
            ),
          ),
        ),
        _PlaylistTile(
          icon: Icons.new_releases_rounded,
          title: 'Recently Added',
          subtitle: '${library.recentlyAddedSongs.take(50).length} tracks',
          gradientColors: const [RyuColors.blue, RyuColors.violet],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PlaylistDetailScreen(
                smartKind: SmartPlaylistKind.recentlyAdded,
              ),
            ),
          ),
        ),
        if (customPlaylists.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              'YOUR PLAYLISTS',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: RyuColors.textSecondary,
              ),
            ),
          ),
          for (final pl in customPlaylists)
            _PlaylistTile(
              icon: Icons.queue_music_rounded,
              title: pl.name,
              subtitle: pl.description.isNotEmpty
                  ? '${pl.songIds.length} tracks • ${pl.description}'
                  : '${pl.songIds.length} tracks',
              gradientColors: [
                RyuColors.violet.withValues(alpha: 0.75),
                RyuColors.surfaceHigh,
              ],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailScreen(playlistId: pl.id),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RyuColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accent.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: RyuColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: RyuColors.textSecondary, fontSize: 12.5),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: RyuColors.textSecondary,
      ),
      onTap: onTap,
    );
  }
}
