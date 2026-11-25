import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ryu/core/controllers/audio_controller.dart';
import 'package:ryu/core/controllers/library_controller.dart';
import 'package:ryu/core/models/history_entry.dart';
import 'package:ryu/core/models/playlist.dart';
import 'package:ryu/core/models/song.dart';
import 'package:ryu/core/ryu_scope.dart';
import 'package:ryu/core/services/storage_service.dart';
import 'package:ryu/core/theme/ryu_theme.dart';
import 'package:ryu/core/utils/duration_formatter.dart';
import 'package:ryu/core/utils/lrc_parser.dart';
import 'package:ryu/features/player/now_playing_screen.dart';

void main() {
  test('DurationFormatter formats minutes and hours properly', () {
    expect(DurationFormatter.format(const Duration(seconds: 65)), '1:05');
    expect(
      DurationFormatter.format(const Duration(hours: 1, minutes: 2, seconds: 9)),
      '1:02:09',
    );
    expect(
      DurationFormatter.formatRemaining(
        const Duration(seconds: 30),
        const Duration(seconds: 90),
      ),
      '-1:00',
    );
  });

  test('LrcParser parses synced timestamps, metadata, and offset properly', () {
    const sample = """
[ti:Test Track]
[ar:RYU Artist]
[al:Midnight Neon]
[offset:+500]
[00:05.00] Line one
[00:10.50] Line two
[00:18.00] Line three
""";
    final lines = LrcParser.parse(sample);
    expect(lines.length, 3);
    expect(lines.first.isSynced, true);
    expect(lines.first.text, 'Line one');
    expect(lines.first.timestamp, const Duration(milliseconds: 4500));
    expect(
      LrcParser.findActiveIndex(lines, const Duration(seconds: 12)),
      1,
    );
  });

  test('Song, RyuPlaylist, and HistoryEntry serialize cleanly', () {
    const song = Song(
      id: 42,
      title: 'Midnight Drive',
      artist: 'RYU',
      album: 'Neon City',
      albumId: 7,
      durationMs: 215000,
      uri: 'content://media/external/audio/media/42',
      trackNumber: 3,
    );
    final restoredSong = Song.fromMap(song.toMap());
    expect(restoredSong, song);
    expect(restoredSong.duration, const Duration(milliseconds: 215000));

    final now = DateTime.utc(2026, 11, 24);
    final playlist = RyuPlaylist(
      id: 'pl_1',
      name: 'Late Night',
      description: 'Synthwave & R&B',
      songIds: const [42],
      createdAt: now,
      updatedAt: now,
    );
    final restoredPlaylist = RyuPlaylist.fromJson(playlist.toJson());
    expect(restoredPlaylist.id, 'pl_1');
    expect(restoredPlaylist.songIds, [42]);

    final entry = HistoryEntry(songId: 42, playedAt: now);
    final restoredEntry = HistoryEntry.fromJson(entry.toJson());
    expect(restoredEntry.songId, 42);
  });

  test('LibraryController notifies listeners and reorders playlist songs',
      () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();

    final library = LibraryController();
    addTearDown(library.dispose);
    var notifications = 0;
    library.addListener(() => notifications++);

    final playlist = await library.createPlaylist(
      'Mix',
      initialSongIds: const [1, 2, 3],
    );
    expect(notifications, greaterThan(0));

    await library.reorderPlaylistSongs(playlist.id, 0, 3);
    expect(library.playlists.first.songIds, [2, 3, 1]);

    await library.reorderPlaylistSongs(playlist.id, 2, 0);
    expect(library.playlists.first.songIds, [1, 2, 3]);

    // Out-of-range indexes must leave the order untouched.
    await library.reorderPlaylistSongs(playlist.id, 9, 0);
    expect(library.playlists.first.songIds, [1, 2, 3]);
  });

  testWidgets('NowPlayingScreen renders cleanly on compact and standard viewports',
      (tester) async {
    final library = LibraryController();
    final audio = AudioController(library: library);
    addTearDown(() {
      audio.dispose();
      library.dispose();
    });

    for (final size in const [Size(360, 640), Size(412, 915)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        RyuScope(
          library: library,
          audio: audio,
          child: MaterialApp(
            theme: RyuTheme.dark(),
            home: const NowPlayingScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
