import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/controllers/library_controller.dart';
import '../../core/models/album.dart';
import '../../core/models/song.dart';
import '../../core/ryu_scope.dart';
import '../../core/services/local_music_scanner.dart';
import '../../core/theme/ryu_colors.dart';
import '../../shared/widgets/artwork_image.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/song_tile.dart';
import '../library/album_detail_screen.dart';
import '../library/history_screen.dart';
import '../library/playlist_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5) return 'Still up?';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scope = RyuScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([scope.library, scope.audio]),
      builder: (context, _) {
        final library = scope.library;
        final recentlyPlayed = library.recentlyPlayedSongs;
        final featuredAlbums = library.featuredAlbums;
        final recommendations = library.recommendedSongs;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                RyuColors.violet.withValues(alpha: 0.22),
                RyuColors.void_,
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: RyuColors.violet,
              backgroundColor: RyuColors.surface,
              onRefresh: () => library.scanLibrary(requestPermission: true),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 165),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (r) =>
                              RyuColors.accent.createShader(r),
                          child: Text(
                            'RYU',
                            style: t.labelLarge?.copyWith(
                              letterSpacing: 6,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _greeting,
                          style: t.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your Personal Music Experience',
                          style: t.bodyMedium?.copyWith(
                            color: RyuColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (library.permissionStatus !=
                      AudioPermissionStatus.granted) ...[
                    const SizedBox(height: 24),
                    _PermissionPromptCard(library: library),
                  ],

                  // 1. QUICK PLAYLISTS
                  const SectionHeader('Quick playlists'),
                  _buildQuickPlaylistsGrid(context, scope),

                  // 2. RECENTLY PLAYED
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Recently played',
                            style: t.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (recentlyPlayed.isNotEmpty)
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const HistoryScreen(),
                              ),
                            ),
                            child: const Text('See all'),
                          ),
                      ],
                    ),
                  ),
                  if (recentlyPlayed.isEmpty)
                    const EmptyState(
                      icon: Icons.history_rounded,
                      message:
                          'Nothing played yet. Tap any song from your library to start listening.',
                    )
                  else
                    SizedBox(
                      height: 186,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        scrollDirection: Axis.horizontal,
                        itemCount: recentlyPlayed.take(12).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final song = recentlyPlayed[index];
                          return _RecentSongCard(
                            song: song,
                            onTap: () => scope.audio.playSongs(
                              recentlyPlayed,
                              initialIndex: index,
                              contextLabel: 'Recently Played',
                            ),
                          );
                        },
                      ),
                    ),

                  // 3. FEATURED ALBUMS
                  const SectionHeader(
                    'Featured albums',
                    subtitle: 'Albums indexed from your local storage',
                  ),
                  if (featuredAlbums.isEmpty)
                    EmptyState(
                      icon: Icons.album_rounded,
                      message: library.isScanning
                          ? 'Scanning your Android device for albums...'
                          : 'No local albums detected yet. Add music files to your device and pull down to refresh.',
                    )
                  else
                    SizedBox(
                      height: 204,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        scrollDirection: Axis.horizontal,
                        itemCount: featuredAlbums.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final album = featuredAlbums[index];
                          return _FeaturedAlbumCard(
                            album: album,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    AlbumDetailScreen(album: album),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // 4. RECOMMENDATIONS
                  const SectionHeader(
                    'Recommendations',
                    subtitle: 'Picked from your local collection',
                  ),
                  if (recommendations.isEmpty)
                    const EmptyState(
                      icon: Icons.auto_awesome_rounded,
                      message:
                          'Personalized recommendations will appear once local tracks are indexed.',
                    )
                  else
                    for (int i = 0; i < recommendations.length; i++)
                      SongTile(
                        song: recommendations[i],
                        onTap: () => scope.audio.playSongs(
                          recommendations,
                          initialIndex: i,
                          contextLabel: 'Recommended',
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickPlaylistsGrid(BuildContext context, RyuScope scope) {
    final library = scope.library;
    final items = <_QuickPlaylistItem>[
      _QuickPlaylistItem(
        title: 'Favorites',
        countText: '${library.favoriteSongs.length} tracks',
        icon: Icons.favorite_rounded,
        colors: const [RyuColors.violet, RyuColors.indigo],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PlaylistDetailScreen(
              smartKind: SmartPlaylistKind.favorites,
            ),
          ),
        ),
        onPlay: library.favoriteSongs.isEmpty
            ? null
            : () => scope.audio.playSongs(
                  library.favoriteSongs,
                  contextLabel: 'Favorites',
                ),
      ),
      _QuickPlaylistItem(
        title: 'Shuffle All',
        countText: '${library.songs.length} tracks',
        icon: Icons.shuffle_rounded,
        colors: const [RyuColors.indigo, RyuColors.blue],
        onTap: library.songs.isEmpty
            ? () {}
            : () => scope.audio.playSongs(
                  library.songs,
                  contextLabel: 'All Songs',
                  forceShuffle: true,
                ),
        onPlay: library.songs.isEmpty
            ? null
            : () => scope.audio.playSongs(
                  library.songs,
                  contextLabel: 'All Songs',
                  forceShuffle: true,
                ),
      ),
      _QuickPlaylistItem(
        title: 'Most Played',
        countText: '${library.mostPlayedSongs.length} tracks',
        icon: Icons.trending_up_rounded,
        colors: const [RyuColors.blue, RyuColors.violet],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PlaylistDetailScreen(
              smartKind: SmartPlaylistKind.mostPlayed,
            ),
          ),
        ),
        onPlay: library.mostPlayedSongs.isEmpty
            ? null
            : () => scope.audio.playSongs(
                  library.mostPlayedSongs,
                  contextLabel: 'Most Played',
                ),
      ),
      _QuickPlaylistItem(
        title: 'Recently Added',
        countText: '${library.recentlyAddedSongs.take(50).length} tracks',
        icon: Icons.new_releases_rounded,
        colors: [
          RyuColors.violet.withValues(alpha: 0.85),
          RyuColors.surfaceHigh,
        ],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PlaylistDetailScreen(
              smartKind: SmartPlaylistKind.recentlyAdded,
            ),
          ),
        ),
        onPlay: library.recentlyAddedSongs.isEmpty
            ? null
            : () => scope.audio.playSongs(
                  library.recentlyAddedSongs.take(50).toList(),
                  contextLabel: 'Recently Added',
                ),
      ),
    ];

    for (final pl in library.playlists.take(2)) {
      final plSongs = library.resolvePlaylistSongs(pl);
      items.add(
        _QuickPlaylistItem(
          title: pl.name,
          countText: '${plSongs.length} tracks',
          icon: Icons.queue_music_rounded,
          colors: const [RyuColors.surfaceHigh, RyuColors.indigo],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlaylistDetailScreen(playlistId: pl.id),
            ),
          ),
          onPlay: plSongs.isEmpty
              ? null
              : () => scope.audio.playSongs(
                    plSongs,
                    contextLabel: pl.name,
                  ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.65,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _QuickPlaylistCard(item: items[i]),
      ),
    );
  }
}

class _PermissionPromptCard extends StatelessWidget {
  const _PermissionPromptCard({required this.library});
  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    final permDenied =
        library.permissionStatus == AudioPermissionStatus.permanentlyDenied;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RyuColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: RyuColors.violet.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.library_music_rounded, color: RyuColors.violet),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Grant Audio Access',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Allow RYU to scan local music on your device.',
                  style: TextStyle(
                    color: RyuColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              if (permDenied) {
                openAppSettings();
              } else {
                library.scanLibrary(requestPermission: true);
              }
            },
            child: Text(permDenied ? 'Settings' : 'Allow'),
          ),
        ],
      ),
    );
  }
}

class _QuickPlaylistItem {
  const _QuickPlaylistItem({
    required this.title,
    required this.countText,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.onPlay,
  });

  final String title;
  final String countText;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
}

class _QuickPlaylistCard extends StatelessWidget {
  const _QuickPlaylistCard({required this.item});
  final _QuickPlaylistItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: RyuColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: item.colors,
                ),
              ),
              child: Icon(item.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    item.countText,
                    style: const TextStyle(
                      color: RyuColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (item.onPlay != null)
              IconButton(
                onPressed: item.onPlay,
                icon: const Icon(
                  Icons.play_arrow_rounded,
                  size: 20,
                  color: RyuColors.violet,
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentSongCard extends StatelessWidget {
  const _RecentSongCard({required this.song, required this.onTap});
  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 134,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArtworkImage(
              songId: song.id,
              albumId: song.albumId,
              size: 134,
              borderRadius: 20,
              iconSize: 40,
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: RyuColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedAlbumCard extends StatelessWidget {
  const _FeaturedAlbumCard({required this.album, required this.onTap});
  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArtworkImage(
              songId: album.coverSongId,
              albumId: album.id,
              size: 150,
              borderRadius: 22,
              iconSize: 44,
            ),
            const SizedBox(height: 8),
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
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
      ),
    );
  }
}
