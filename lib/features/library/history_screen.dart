import 'package:flutter/material.dart';
import '../../core/models/song.dart';
import '../../core/ryu_scope.dart';
import '../../core/theme/ryu_colors.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/mini_player.dart';
import '../../shared/widgets/song_tile.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scope = RyuScope.of(context);

    return ListenableBuilder(
      listenable: scope.library,
      builder: (context, _) {
        final entries = scope.library.history;
        final resolved = <(Song, DateTime)>[];
        for (final entry in entries) {
          final song = scope.library.songById(entry.songId);
          if (song != null) {
            resolved.add((song, entry.playedAt));
          }
        }

        return Scaffold(
          backgroundColor: RyuColors.void_,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text(
              'Listening History',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              if (resolved.isNotEmpty)
                TextButton(
                  onPressed: () => scope.library.clearHistory(),
                  child: const Text('Clear'),
                ),
            ],
          ),
          body: Stack(
            children: [
              if (resolved.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: EmptyState(
                    icon: Icons.history_rounded,
                    message:
                        'Your playback history is empty. Play any local track to start logging your sessions.',
                  ),
                )
              else
                ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 130),
                  itemCount: resolved.length,
                  itemBuilder: (context, index) {
                    final (song, playedAt) = resolved[index];
                    return SongTile(
                      song: song,
                      subtitleOverride:
                          '${song.artist} • ${_relativeTime(playedAt)}',
                      onTap: () => scope.audio.playSongs(
                        resolved.map((e) => e.$1).toList(),
                        initialIndex: index,
                        contextLabel: 'Listening History',
                      ),
                    );
                  },
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
      },
    );
  }
}
