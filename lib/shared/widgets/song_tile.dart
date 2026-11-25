import 'package:flutter/material.dart';
import '../../core/models/song.dart';
import '../../core/ryu_scope.dart';
import '../../core/theme/ryu_colors.dart';
import '../../core/utils/duration_formatter.dart';
import 'artwork_image.dart';
import 'song_options_sheet.dart';

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.subtitleOverride,
    this.playlistId,
    this.showTrackNumber = false,
  });

  final Song song;
  final VoidCallback onTap;
  final String? subtitleOverride;
  final String? playlistId;
  final bool showTrackNumber;

  @override
  Widget build(BuildContext context) {
    final scope = RyuScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([scope.audio, scope.library]),
      builder: (context, _) {
        final isCurrent = scope.audio.currentSong?.id == song.id;
        final isPlaying = isCurrent && scope.audio.isPlaying;
        final isFav = scope.library.isFavorite(song.id);

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                if (showTrackNumber)
                  SizedBox(
                    width: 30,
                    child: isCurrent
                        ? Icon(
                            isPlaying
                                ? Icons.equalizer_rounded
                                : Icons.pause_rounded,
                            color: RyuColors.violet,
                            size: 20,
                          )
                        : Text(
                            song.trackNumber > 0
                                ? '${song.trackNumber % 100}'
                                : '•',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: RyuColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                  )
                else
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ArtworkImage(
                        songId: song.id,
                        albumId: song.albumId,
                        size: 50,
                        borderRadius: 13,
                      ),
                      if (isCurrent)
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            isPlaying
                                ? Icons.equalizer_rounded
                                : Icons.play_arrow_rounded,
                            color: RyuColors.violet,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isCurrent
                              ? RyuColors.violet
                              : RyuColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitleOverride ??
                            '${song.artist} • ${DurationFormatter.format(song.duration)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RyuColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => scope.library.toggleFavorite(song.id),
                  icon: Icon(
                    isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 20,
                    color: isFav ? RyuColors.violet : RyuColors.textSecondary,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () => SongOptionsSheet.show(
                    context,
                    song,
                    playlistId: playlistId,
                  ),
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: RyuColors.textSecondary,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
