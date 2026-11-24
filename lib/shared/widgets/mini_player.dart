import 'package:flutter/material.dart';
import '../../core/ryu_scope.dart';
import '../../core/theme/ryu_colors.dart';
import '../../features/player/now_playing_screen.dart';
import 'artwork_image.dart';
import 'glass_container.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = RyuScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([scope.audio, scope.library]),
      builder: (context, _) {
        final song = scope.audio.currentSong;
        if (song == null) return const SizedBox.shrink();

        final isPlaying = scope.audio.isPlaying;
        final isFav = scope.library.isFavorite(song.id);
        final palette = scope.audio.ambientPalette;
        final totalMs = scope.audio.duration.inMilliseconds;
        final posMs = scope.audio.position.inMilliseconds;
        final progress =
            totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;

        return GestureDetector(
          onTap: () => NowPlayingScreen.open(context),
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -200) {
              NowPlayingScreen.open(context);
            }
          },
          child: GlassContainer(
            borderRadius: 24,
            blur: 24,
            padding: EdgeInsets.zero,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    palette.primary.withValues(alpha: 0.22),
                    RyuColors.surface.withValues(alpha: 0.45),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'now_playing_art',
                          child: ArtworkImage(
                            songId: song.id,
                            albumId: song.albumId,
                            size: 44,
                            borderRadius: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: RyuColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: RyuColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              scope.library.toggleFavorite(song.id),
                          icon: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 20,
                            color: isFav
                                ? RyuColors.violet
                                : RyuColors.textSecondary,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          onPressed: scope.audio.togglePlayPause,
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 28,
                            color: Colors.white,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          onPressed: scope.audio.seekToNext,
                          icon: const Icon(
                            Icons.skip_next_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 2.5,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        palette.primary,
                      ),
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
}
