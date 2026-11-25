import 'package:flutter/material.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import '../../core/ryu_scope.dart';
import '../../core/theme/ryu_colors.dart';
import '../../shared/widgets/artwork_image.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/mini_player.dart';
import '../../shared/widgets/song_tile.dart';

enum SmartPlaylistKind {
  favorites,
  mostPlayed,
  recentlyAdded,
}

class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({
    super.key,
    this.playlistId,
    this.smartKind,
  }) : assert(playlistId != null || smartKind != null);

  final String? playlistId;
  final SmartPlaylistKind? smartKind;

  @override
  Widget build(BuildContext context) {
    final scope = RyuScope.of(context);

    return ListenableBuilder(
      listenable: scope.library,
      builder: (context, _) {
        String title = '';
        String subtitle = '';
        List<Song> tracks = [];
        RyuPlaylist? customPlaylist;

        if (playlistId != null) {
          final idx = scope.library.playlists.indexWhere(
            (p) => p.id == playlistId,
          );
          if (idx >= 0) {
            customPlaylist = scope.library.playlists[idx];
            title = customPlaylist.name;
            tracks = scope.library.resolvePlaylistSongs(customPlaylist);
            subtitle = customPlaylist.description.isNotEmpty
                ? customPlaylist.description
                : '${tracks.length} tracks';
          } else {
            title = 'Playlist';
          }
        } else {
          switch (smartKind!) {
            case SmartPlaylistKind.favorites:
              title = 'Favorites';
              tracks = scope.library.favoriteSongs;
              subtitle = '${tracks.length} liked tracks';
            case SmartPlaylistKind.mostPlayed:
              title = 'Most Played';
              tracks = scope.library.mostPlayedSongs;
              subtitle = '${tracks.length} tracks';
            case SmartPlaylistKind.recentlyAdded:
              title = 'Recently Added';
              tracks = scope.library.recentlyAddedSongs.take(50).toList();
              subtitle = '${tracks.length} newest local tracks';
          }
        }

        final Widget headerSection = Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: RyuColors.textSecondary,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: tracks.isEmpty
                            ? null
                            : () => scope.audio.playSongs(
                                  tracks,
                                  contextLabel: title,
                                ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: tracks.isEmpty
                            ? null
                            : () => scope.audio.playSongs(
                                  tracks,
                                  contextLabel: title,
                                  forceShuffle: true,
                                ),
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('Shuffle'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

        // Drag-to-reorder only when every saved song is still resolvable,
        // so visible indices always match the stored playlist order.
        final RyuPlaylist? editablePlaylist = customPlaylist;
        final String? reorderId = (editablePlaylist != null &&
                tracks.isNotEmpty &&
                tracks.length == editablePlaylist.songIds.length)
            ? editablePlaylist.id
            : null;

        return Scaffold(
          backgroundColor: RyuColors.void_,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              if (customPlaylist != null) ...[
                IconButton(
                  tooltip: 'Add Songs',
                  icon: const Icon(Icons.playlist_add_rounded),
                  onPressed: () => _openAddSongsPicker(
                    context,
                    scope,
                    customPlaylist!,
                  ),
                ),
                PopupMenuButton<String>(
                  color: RyuColors.surface,
                  onSelected: (value) async {
                    if (value == 'rename') {
                      await _renamePlaylistDialog(
                        context,
                        scope,
                        customPlaylist!,
                      );
                    } else if (value == 'delete') {
                      await scope.library.deletePlaylist(customPlaylist!.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text('Rename Playlist'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete Playlist',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          body: Stack(
            children: [
              if (reorderId != null)
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: headerSection),
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 130),
                      sliver: SliverReorderableList(
                        itemCount: tracks.length,
                        onReorder: (oldIndex, newIndex) =>
                            scope.library.reorderPlaylistSongs(
                          reorderId,
                          oldIndex,
                          newIndex,
                        ),
                        itemBuilder: (context, i) => Material(
                          key: ValueKey('playlist_track_${tracks[i].id}'),
                          color: Colors.transparent,
                          child: Row(
                            children: [
                              Expanded(
                                child: SongTile(
                                  song: tracks[i],
                                  playlistId: reorderId,
                                  onTap: () => scope.audio.playSongs(
                                    tracks,
                                    initialIndex: i,
                                    contextLabel: title,
                                  ),
                                ),
                              ),
                              ReorderableDragStartListener(
                                index: i,
                                child: const Padding(
                                  padding: EdgeInsets.only(right: 16),
                                  child: Icon(
                                    Icons.drag_handle_rounded,
                                    color: RyuColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                ListView(
                  padding: const EdgeInsets.only(bottom: 130),
                  children: [
                    headerSection,
                    if (tracks.isEmpty)
                      EmptyState(
                        icon: Icons.queue_music_rounded,
                        message: customPlaylist != null
                            ? 'This playlist has no tracks yet. Tap the + icon at the top right to add songs.'
                            : 'No tracks in $title yet.',
                      )
                    else
                      for (int i = 0; i < tracks.length; i++)
                        SongTile(
                          song: tracks[i],
                          playlistId: customPlaylist?.id,
                          onTap: () => scope.audio.playSongs(
                            tracks,
                            initialIndex: i,
                            contextLabel: title,
                          ),
                        ),
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
      },
    );
  }

  Future<void> _renamePlaylistDialog(
    BuildContext context,
    RyuScope scope,
    RyuPlaylist playlist,
  ) async {
    final nameCtrl = TextEditingController(text: playlist.name);
    final descCtrl = TextEditingController(text: playlist.description);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RyuColors.surface,
        title: const Text('Edit Playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      await scope.library.renamePlaylist(
        playlist.id,
        nameCtrl.text,
        newDescription: descCtrl.text,
      );
    }
    nameCtrl.dispose();
    descCtrl.dispose();
  }

  Future<void> _openAddSongsPicker(
    BuildContext context,
    RyuScope scope,
    RyuPlaylist playlist,
  ) async {
    final selected = <int>{};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RyuColors.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final allSongs = scope.library.songs;
            return DraggableScrollableSheet(
              initialChildSize: 0.78,
              minChildSize: 0.5,
              maxChildSize: 0.94,
              expand: false,
              builder: (_, scrollCtrl) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Add Songs (${selected.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          FilledButton(
                            onPressed: selected.isEmpty
                                ? null
                                : () async {
                                    await scope.library.addSongsToPlaylist(
                                      playlist.id,
                                      selected.toList(),
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        itemCount: allSongs.length,
                        itemBuilder: (_, i) {
                          final song = allSongs[i];
                          final already = playlist.songIds.contains(song.id);
                          final checked = already || selected.contains(song.id);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: already
                                ? null
                                : (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        selected.add(song.id);
                                      } else {
                                        selected.remove(song.id);
                                      }
                                    });
                                  },
                            secondary: ArtworkImage(
                              songId: song.id,
                              albumId: song.albumId,
                              size: 42,
                              borderRadius: 10,
                            ),
                            title: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
