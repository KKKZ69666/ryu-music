import 'package:flutter/material.dart';
import '../../core/models/album.dart';
import '../../core/ryu_scope.dart';
import '../../core/theme/ryu_colors.dart';
import '../../core/utils/duration_formatter.dart';
import '../../shared/widgets/artwork_image.dart';
import '../../shared/widgets/mini_player.dart';
import '../../shared/widgets/song_tile.dart';

class AlbumDetailScreen extends StatelessWidget {
  const AlbumDetailScreen({super.key, required this.album});
  final Album album;

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
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          RyuColors.indigo.withValues(alpha: 0.35),
                          RyuColors.void_,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          ArtworkImage(
                            songId: album.coverSongId,
                            albumId: album.id,
                            size: 165,
                            borderRadius: 24,
                            iconSize: 56,
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              album.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${album.artist} • ${album.trackCount} tracks • ${DurationFormatter.format(album.totalDuration)}',
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
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: album.songs.isEmpty
                              ? null
                              : () => scope.audio.playSongs(
                                    album.songs,
                                    contextLabel: album.name,
                                  ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: album.songs.isEmpty
                              ? null
                              : () => scope.audio.playSongs(
                                    album.songs,
                                    contextLabel: album.name,
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
              SliverList.builder(
                itemCount: album.songs.length,
                itemBuilder: (context, index) {
                  final song = album.songs[index];
                  return SongTile(
                    song: song,
                    showTrackNumber: true,
                    onTap: () => scope.audio.playSongs(
                      album.songs,
                      initialIndex: index,
                      contextLabel: album.name,
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
