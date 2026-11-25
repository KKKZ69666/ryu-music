import 'package:flutter/material.dart';
import '../../core/models/artist.dart';
import '../../core/ryu_scope.dart';
import '../../core/theme/ryu_colors.dart';
import '../../shared/widgets/artwork_image.dart';
import '../../shared/widgets/mini_player.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/song_tile.dart';
import 'album_detail_screen.dart';

class ArtistDetailScreen extends StatelessWidget {
  const ArtistDetailScreen({super.key, required this.artist});
  final Artist artist;

  @override
  Widget build(BuildContext context) {
    final scope = RyuScope.of(context);

    return Scaffold(
      backgroundColor: RyuColors.void_,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: RyuColors.void_,
                expandedHeight: 260,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          RyuColors.violet.withValues(alpha: 0.32),
                          RyuColors.void_,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          ArtworkImage(
                            songId: artist.coverSongId,
                            albumId: artist.coverAlbumId,
                            size: 130,
                            borderRadius: 65,
                            iconSize: 48,
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              artist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${artist.albumCount} albums • ${artist.trackCount} tracks',
                            style: const TextStyle(
                              color: RyuColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: artist.songs.isEmpty
                              ? null
                              : () => scope.audio.playSongs(
                                    artist.songs,
                                    contextLabel: artist.name,
                                  ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: artist.songs.isEmpty
                              ? null
                              : () => scope.audio.playSongs(
                                    artist.songs,
                                    contextLabel: artist.name,
                                    forceShuffle: true,
                                  ),
                          icon: const Icon(Icons.shuffle_rounded),
                          label: const Text('Shuffle'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (artist.albums.isNotEmpty) ...[
                const SliverToBoxAdapter(child: SectionHeader('Albums')),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 185,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      scrollDirection: Axis.horizontal,
                      itemCount: artist.albums.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final album = artist.albums[index];
                        return GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AlbumDetailScreen(album: album),
                            ),
                          ),
                          child: SizedBox(
                            width: 136,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ArtworkImage(
                                  songId: album.coverSongId,
                                  albumId: album.id,
                                  size: 136,
                                  borderRadius: 18,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  album.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${album.trackCount} tracks',
                                  style: const TextStyle(
                                    color: RyuColors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SectionHeader('Tracks')),
              SliverList.builder(
                itemCount: artist.songs.length,
                itemBuilder: (context, index) {
                  final song = artist.songs[index];
                  return SongTile(
                    song: song,
                    onTap: () => scope.audio.playSongs(
                      artist.songs,
                      initialIndex: index,
                      contextLabel: artist.name,
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
          const Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(child: MiniPlayer()),
          ),
        ],
      ),
    );
  }
}
