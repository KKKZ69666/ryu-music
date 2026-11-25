import 'package:flutter/material.dart';
import '../../core/models/song.dart';
import '../../core/ryu_scope.dart';
import '../../core/theme/ryu_colors.dart';
import '../../shared/widgets/glass_container.dart';
import '../../shared/widgets/artwork_image.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = RyuScope.of(context);
    final history = scope.library.history;
    final songs = scope.library.songs;
    final playCounts = scope.library.playCounts;

    int totalMinutes = 0;
    for (final entry in history) {
      final song = songs.where((s) => s.id == entry.songId).firstOrNull;
      totalMinutes += song != null ? (song.duration.inMinutes > 0 ? song.duration.inMinutes : 3) : 3;
    }

    final sortedSongIds = playCounts.keys.toList()
      ..sort((a, b) => (playCounts[b] ?? 0).compareTo(playCounts[a] ?? 0));
    
    final topSongs = sortedSongIds
        .take(5)
        .map((id) => songs.where((s) => s.id == id).firstOrNull)
        .whereType<Song>()
        .toList();

    final artistCounts = <String, int>{};
    playCounts.forEach((songId, count) {
      final song = songs.where((s) => s.id == songId).firstOrNull;
      if (song != null) {
        artistCounts[song.artist] = (artistCounts[song.artist] ?? 0) + count;
      }
    });
    final sortedArtists = artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topArtists = sortedArtists.take(5).toList();

    return Scaffold(
      backgroundColor: RyuColors.void_,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Music Analysis',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: RyuColors.violet.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.insights_rounded, color: RyuColors.violet, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Listening Insights',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Local playback analytics & statistics',
                          style: TextStyle(color: RyuColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _StatMetricBox(
                        label: 'Total Time',
                        value: '${totalMinutes ~/ 60}h ${totalMinutes % 60}m',
                        icon: Icons.timer_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatMetricBox(
                        label: 'Tracks Played',
                        value: history.length.toString(),
                        icon: Icons.headphones_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatMetricBox(
                        label: 'Library Size',
                        value: songs.length.toString(),
                        icon: Icons.library_music_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Most Played Tracks',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (topSongs.isEmpty)
            const GlassContainer(
              borderRadius: 18,
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No playback history yet. Play some music to see your top tracks!',
                  style: TextStyle(color: RyuColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...topSongs.asMap().entries.map((entry) {
              final idx = entry.key;
              final song = entry.value;
              final plays = playCounts[song.id] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Text(
                        '#${idx + 1}',
                        style: const TextStyle(color: RyuColors.violet, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(width: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: ArtworkImage(
                            songId: song.id,
                            albumId: song.albumId,
                            size: 44,
                            borderRadius: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: RyuColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: RyuColors.violet.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$plays plays',
                          style: const TextStyle(color: RyuColors.violet, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
          const Text(
            'Top Artists',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (topArtists.isEmpty)
            const GlassContainer(
              borderRadius: 18,
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No artist statistics available yet.',
                  style: TextStyle(color: RyuColors.textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            SizedBox(
              height: 95,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: topArtists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final artistEntry = topArtists[index];
                  return GlassContainer(
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: RyuColors.violet.withValues(alpha: 0.3),
                          ),
                          child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          artistEntry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StatMetricBox extends StatelessWidget {
  const _StatMetricBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: RyuColors.violet, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: RyuColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
