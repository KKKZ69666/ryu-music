import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../core/models/lyric_line.dart';
import '../../core/models/song.dart';
import '../../core/ryu_scope.dart';
import '../../core/services/lyrics_service.dart';
import '../../core/theme/ryu_colors.dart';
import '../../core/utils/duration_formatter.dart';
import '../../core/utils/lrc_parser.dart';
import '../../shared/widgets/glass_container.dart';

class LyricsView extends StatefulWidget {
  const LyricsView({super.key});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  int _lastActiveIndex = -1;
  int? _lastSongId;
  bool _userScrolling = false;
  Timer? _resumeScrollTimer;
  bool _fetchingOnline = false;
  String? _statusNote;

  @override
  void dispose() {
    _resumeScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onUserScroll() {
    if (!_userScrolling) {
      setState(() => _userScrolling = true);
    }
    _resumeScrollTimer?.cancel();
    _resumeScrollTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _userScrolling = false);
        _scrollToLine(_lastActiveIndex, force: true);
      }
    });
  }

  void _scrollToLine(int index, {bool force = false}) {
    if (index < 0) return;
    if (_userScrolling && !force) return;
    final key = _lineKeys[index];
    final ctx = key?.currentContext;
    if (ctx == null) return;

    Scrollable.ensureVisible(
      ctx,
      alignment: 0.34,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _importLrc(Song song) async {
    try {
      final doc = await LyricsService.instance.importLrcFromDevice(song);
      if (!mounted) return;
      if (doc != null) {
        RyuScope.of(context).audio.setLoadedLyrics(doc);
        setState(() => _statusNote = null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusNote = 'Could not read .lrc file: $e');
    }
  }

  Future<void> _fetchOnline(Song song) async {
    setState(() {
      _fetchingOnline = true;
      _statusNote = null;
    });
    try {
      final doc = await LyricsService.instance.fetchFromLrclib(song);
      if (!mounted) return;
      if (doc != null) {
        RyuScope.of(context).audio.setLoadedLyrics(doc);
        setState(() => _statusNote = null);
      } else {
        setState(
          () => _statusNote =
              'No synced lyrics found on LRCLIB for "${song.title}". You can import a local .lrc file or paste lyrics manually.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _statusNote =
            'Unable to reach LRCLIB right now. Check your internet connection or import a local .lrc file.',
      );
    } finally {
      if (mounted) setState(() => _fetchingOnline = false);
    }
  }

  Future<void> _showPasteDialog(Song song, {String? initialText}) async {
    final controller = TextEditingController(text: initialText ?? '');
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RyuColors.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste LRC or Plain Lyrics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Supports timestamped [mm:ss.xx] LRC lines for Apple Music-style synced scrolling, or plain lyrics.',
              style: TextStyle(color: RyuColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 9,
              autofocus: true,
              style: const TextStyle(fontSize: 13.5, height: 1.5),
              decoration: InputDecoration(
                hintText:
                    '[00:12.40] First line of lyrics...\n[00:16.80] Second line of lyrics...',
                filled: true,
                fillColor: RyuColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, controller.text),
                  child: const Text('Save Lyrics'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();

    if (saved != null && saved.trim().isNotEmpty && mounted) {
      final doc = await LyricsService.instance.saveCustomLyrics(
        song: song,
        rawText: saved,
      );
      if (mounted && doc != null) {
        RyuScope.of(context).audio.setLoadedLyrics(doc);
        setState(() => _statusNote = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = RyuScope.of(context);

    return ListenableBuilder(
      listenable: scope.audio,
      builder: (context, _) {
        final song = scope.audio.currentSong;
        if (song == null) return const SizedBox.shrink();

        if (_lastSongId != song.id) {
          _lastSongId = song.id;
          _lastActiveIndex = -1;
          _lineKeys.clear();
          _userScrolling = false;
          _statusNote = null;
        }

        if (scope.audio.isLoadingLyrics) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final doc = scope.audio.currentLyrics;
        if (doc == null || doc.isEmpty) {
          return _buildEmptyLyrics(song);
        }

        return StreamBuilder<Duration>(
          stream: scope.audio.positionStream,
          initialData: scope.audio.position,
          builder: (context, snapshot) {
            final pos = snapshot.data ?? Duration.zero;
            final activeIndex = doc.isSynced
                ? LrcParser.findActiveIndex(doc.lines, pos)
                : -1;

            if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
              _lastActiveIndex = activeIndex;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _scrollToLine(activeIndex);
              });
            }

            return Stack(
              children: [
                NotificationListener<UserScrollNotification>(
                  onNotification: (notification) {
                    if (notification.direction != ScrollDirection.idle) {
                      _onUserScroll();
                    }
                    return false;
                  },
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.white,
                        Colors.white,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.08, 0.88, 1.0],
                    ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(28, 48, 28, 160),
                      itemCount: doc.lines.length + 1,
                      itemBuilder: (context, index) {
                        if (index == doc.lines.length) {
                          return _buildLyricsFooter(song, doc);
                        }

                        final line = doc.lines[index];
                        final key = _lineKeys.putIfAbsent(
                          index,
                          () => GlobalKey(),
                        );
                        final isActive = doc.isSynced && index == activeIndex;
                        final isPast = doc.isSynced &&
                            activeIndex >= 0 &&
                            index < activeIndex;

                        final double opacity = !doc.isSynced
                            ? 0.92
                            : isActive
                                ? 1.0
                                : isPast
                                    ? 0.30
                                    : 0.45;

                        return GestureDetector(
                          key: key,
                          behavior: HitTestBehavior.opaque,
                          onTap: line.isSynced
                              ? () {
                                  HapticFeedback.selectionClick();
                                  scope.audio.seek(line.timestamp!);
                                  setState(() => _userScrolling = false);
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: AnimatedScale(
                              scale: isActive ? 1.03 : 1.0,
                              alignment: Alignment.centerLeft,
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                              child: AnimatedOpacity(
                                opacity: opacity,
                                duration: const Duration(milliseconds: 260),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (line.isSynced && isActive)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          DurationFormatter.format(
                                            line.timestamp!,
                                          ),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.1,
                                            color: Colors.white.withValues(
                                              alpha: 0.65,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Text(
                                      line.text,
                                      style: TextStyle(
                                        fontSize: isActive ? 29 : 26,
                                        height: 1.28,
                                        fontWeight: isActive
                                            ? FontWeight.w900
                                            : FontWeight.w800,
                                        letterSpacing: -0.4,
                                        color: Colors.white,
                                        shadows: isActive
                                            ? [
                                                Shadow(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.32),
                                                  blurRadius: 18,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (_userScrolling && doc.isSynced && activeIndex >= 0)
                  Positioned(
                    right: 24,
                    bottom: 20,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _userScrolling = false);
                        _scrollToLine(activeIndex, force: true);
                      },
                      child: const GlassContainer(
                        borderRadius: 20,
                        blur: 18,
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.my_location_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Sync',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLyricsFooter(Song song, LyricsDocument doc) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Source: ${doc.source.label}${doc.isSynced ? ' • Tap any line to seek' : ' • Unsynced lyrics'}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChip(
                icon: Icons.folder_open_rounded,
                label: 'Import .lrc',
                onTap: () => _importLrc(song),
              ),
              _ActionChip(
                icon: Icons.edit_note_rounded,
                label: 'Edit',
                onTap: () => _showPasteDialog(song, initialText: doc.rawText),
              ),
              _ActionChip(
                icon: Icons.delete_outline_rounded,
                label: 'Reset',
                onTap: () async {
                  await LyricsService.instance.clearSavedLyrics(song.id);
                  if (mounted) {
                    await RyuScope.of(context)
                        .audio
                        .refreshLyricsForCurrentSong();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLyrics(Song song) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: GlassContainer(
          borderRadius: 28,
          blur: 20,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lyrics_rounded,
                size: 40,
                color: Colors.white,
              ),
              const SizedBox(height: 14),
              const Text(
                'No Lyrics Found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'RYU automatically checks sidecar .lrc files and embedded audio tags. You can also import a .lrc file, paste lyrics, or search LRCLIB.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              if (_statusNote != null) ...[
                const SizedBox(height: 12),
                Text(
                  _statusNote!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _importLrc(song),
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Import .lrc File'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _fetchingOnline ? null : () => _fetchOnline(song),
                  icon: _fetchingOnline
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined),
                  label: Text(
                    _fetchingOnline
                        ? 'Searching LRCLIB...'
                        : 'Fetch Synced Lyrics (LRCLIB)',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _showPasteDialog(song),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Paste Lyrics Manually'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
