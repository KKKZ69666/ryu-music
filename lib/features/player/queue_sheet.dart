import 'package:flutter/material.dart';
import '../../core/ryu_scope.dart';
import '../../core/theme/ryu_colors.dart';
import '../../core/utils/duration_formatter.dart';
import '../../shared/widgets/artwork_image.dart';

class QueueView extends StatelessWidget {
  const QueueView({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = RyuScope.of(context);

    return ListenableBuilder(
      listenable: scope.audio,
      builder: (context, _) {
        final queue = scope.audio.queue;
        final currentIndex = scope.audio.currentIndex;

        if (queue.isEmpty) {
          return const Center(
            child: Text(
              'Queue is empty',
              style: TextStyle(color: RyuColors.textSecondary),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Playing Queue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${queue.length} tracks • From ${scope.audio.queueContextLabel}',
                          style: const TextStyle(
                            color: RyuColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      scope.audio.clearQueue();
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.only(bottom: 32),
                itemCount: queue.length,
                onReorder: scope.audio.moveQueueItem,
                proxyDecorator: (child, __, ___) => Material(
                  color: RyuColors.surfaceHigh.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                  child: child,
                ),
                itemBuilder: (context, index) {
                  final song = queue[index];
                  final isCurrent = index == currentIndex;

                  return Dismissible(
                    key: ValueKey('q_${song.id}_$index'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      color: Colors.redAccent.withValues(alpha: 0.35),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (_) => scope.audio.removeFromQueue(index),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 2,
                      ),
                      onTap: () => scope.audio.skipToQueueIndex(index),
                      leading: Stack(
                        alignment: Alignment.center,
                        children: [
                          ArtworkImage(
                            songId: song.id,
                            albumId: song.albumId,
                            size: 46,
                            borderRadius: 12,
                          ),
                          if (isCurrent)
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.equalizer_rounded,
                                color: RyuColors.violet,
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isCurrent
                              ? RyuColors.violet
                              : RyuColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${song.artist} • ${DurationFormatter.format(song.duration)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RyuColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(
                          Icons.drag_handle_rounded,
                          color: RyuColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
