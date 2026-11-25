import 'package:flutter/material.dart';
import '../../core/models/song.dart';
import '../../core/ryu_scope.dart';
import '../../core/theme/ryu_colors.dart';
import '../../core/utils/duration_formatter.dart';
import '../../features/library/album_detail_screen.dart';
import '../../features/library/artist_detail_screen.dart';
import 'artwork_image.dart';
import 'glass_container.dart';

class SongOptionsSheet extends StatelessWidget {
  const SongOptionsSheet({
    super.key,
    required this.song,
    this.playlistId,
  });

  final Song song;
  final String? playlistId;

  static Future<void> show(
    BuildContext context,
    Song song, {
    String? playlistId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SongOptionsSheet(song: song, playlistId: playlistId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = RyuScope.of(context);
    final isFav = scope.library.isFavorite(song.id);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GlassContainer(
          borderRadius: 28,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ArtworkImage(
                    songId: song.id,
                    albumId: song.albumId,
                    size: 52,
                    borderRadius: 14,
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${song.artist} • ${song.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: RyuColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
              const SizedBox(height: 8),
              _OptionTile(
                icon: Icons.playlist_play_rounded,
                label: 'Play Next',
                onTap: () {
                  navigator.pop();
                  scope.audio.playNextInQueue(song);
                  _snackWith(messenger, 'Playing next: ${song.title}');
                },
              ),
              _OptionTile(
                icon: Icons.queue_music_rounded,
                label: 'Add to Queue',
                onTap: () {
                  navigator.pop();
                  scope.audio.addToQueue(song);
                  _snackWith(messenger, 'Added to queue');
                },
              ),
              _OptionTile(
                icon: isFav
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                iconColor: isFav ? RyuColors.violet : null,
                label: isFav ? 'Remove from Favorites' : 'Add to Favorites',
                onTap: () {
                  navigator.pop();
                  scope.library.toggleFavorite(song.id);
                },
              ),
              _OptionTile(
                icon: Icons.playlist_add_rounded,
                label: 'Add to Playlist',
                onTap: () {
                  final hostContext = navigator.context;
                  navigator.pop();
                  _showAddToPlaylistDialog(
                    hostContext,
                    messenger,
                    scope,
                    song,
                  );
                },
              ),
              if (playlistId != null)
                _OptionTile(
                  icon: Icons.remove_circle_outline_rounded,
                  iconColor: Colors.redAccent,
                  label: 'Remove from this Playlist',
                  onTap: () {
                    navigator.pop();
                    scope.library.removeSongFromPlaylist(playlistId!, song.id);
                  },
                ),
              if (scope.library.albums.any((a) => a.id == song.albumId))
                _OptionTile(
                  icon: Icons.album_rounded,
                  label: 'Go to Album',
                  onTap: () {
                    final album = scope.library.albums.firstWhere(
                      (a) => a.id == song.albumId,
                    );
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute(
                        builder: (_) => AlbumDetailScreen(album: album),
                      ),
                    );
                  },
                ),
              if (scope.library.artists.any((a) => a.name == song.artist))
                _OptionTile(
                  icon: Icons.person_rounded,
                  label: 'Go to Artist',
                  onTap: () {
                    final artist = scope.library.artists.firstWhere(
                      (a) => a.name == song.artist,
                    );
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute(
                        builder: (_) => ArtistDetailScreen(artist: artist),
                      ),
                    );
                  },
                ),
              _OptionTile(
                icon: Icons.info_outline_rounded,
                label: 'Track Details',
                onTap: () {
                  final hostContext = navigator.context;
                  navigator.pop();
                  _showDetailsDialog(hostContext, song);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _snackWith(ScaffoldMessengerState messenger, String msg) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: RyuColors.surfaceHigh,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void _showAddToPlaylistDialog(
    BuildContext hostContext,
    ScaffoldMessengerState messenger,
    RyuScope scope,
    Song song,
  ) {
    if (!hostContext.mounted) return;
    showModalBottomSheet<void>(
      context: hostContext,
      backgroundColor: RyuColors.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: scope.library,
          builder: (_, __) {
            final playlists = scope.library.playlists;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add to Playlist',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _showCreatePlaylistAndAdd(
                              hostContext,
                              messenger,
                              scope,
                              song,
                            );
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('New'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (playlists.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'No custom playlists yet. Tap "New" to create one.',
                          style: TextStyle(color: RyuColors.textSecondary),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: playlists.length,
                          itemBuilder: (_, i) {
                            final pl = playlists[i];
                            final alreadyIn = pl.songIds.contains(song.id);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: RyuColors.accent,
                                ),
                                child: const Icon(
                                  Icons.queue_music_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                pl.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${pl.songIds.length} tracks',
                                style: const TextStyle(
                                  color: RyuColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: alreadyIn
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: RyuColors.violet,
                                    )
                                  : null,
                              onTap: () {
                                scope.library.addSongToPlaylist(pl.id, song.id);
                                Navigator.pop(ctx);
                                _snackWith(messenger, 'Added to ${pl.name}');
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> _showCreatePlaylistAndAdd(
    BuildContext hostContext,
    ScaffoldMessengerState messenger,
    RyuScope scope,
    Song song,
  ) async {
    if (!hostContext.mounted) return;
    final controller = TextEditingController();
    final createdName = await showDialog<String>(
      context: hostContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: RyuColors.surface,
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (createdName != null && createdName.isNotEmpty) {
      await scope.library.createPlaylist(
        createdName,
        initialSongIds: [song.id],
      );
      _snackWith(messenger, 'Created "$createdName"');
    }
  }

  static void _showDetailsDialog(BuildContext hostContext, Song song) {
    if (!hostContext.mounted) return;
    showDialog<void>(
      context: hostContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: RyuColors.surface,
        title: const Text('Track Metadata'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MetaRow('Title', song.title),
            _MetaRow('Artist', song.artist),
            _MetaRow('Album', song.album),
            _MetaRow('Duration', DurationFormatter.format(song.duration)),
            if (song.trackNumber > 0)
              _MetaRow('Track #', song.trackNumber.toString()),
            if (song.filePath != null) _MetaRow('File Path', song.filePath!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: RyuColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor ?? RyuColors.textPrimary, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: iconColor ?? RyuColors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}
