import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/controllers/audio_controller.dart';
import '../../core/models/song.dart';
import '../../core/ryu_scope.dart';
import '../../core/theme/ryu_colors.dart';
import '../../core/utils/duration_formatter.dart';
import '../../shared/widgets/artwork_image.dart';
import '../../shared/widgets/glass_container.dart';
import '../../shared/widgets/song_options_sheet.dart';
import 'lyrics_view.dart';
import 'queue_sheet.dart';

enum _PlayerTab {
  player('Player'),
  lyrics('Lyrics'),
  queue('Queue');

  const _PlayerTab(this.label);
  final String label;
}

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  static Future<void> open(BuildContext context, {int initialTabIndex = 0}) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) =>
            NowPlayingScreen(initialTabIndex: initialTabIndex),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  late _PlayerTab _tab;
  double? _dragSeekValue;

  @override
  void initState() {
    super.initState();
    _tab = _PlayerTab.values[widget.initialTabIndex.clamp(0, 2)];
  }

  @override
  Widget build(BuildContext context) {
    final scope = RyuScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([scope.audio, scope.library]),
      builder: (context, _) {
        final song = scope.audio.currentSong;
        if (song == null) {
          return Scaffold(
            backgroundColor: RyuColors.void_,
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: const Center(child: Text('No track playing')),
          );
        }

        final palette = scope.audio.ambientPalette;
        final isFav = scope.library.isFavorite(song.id);

        return Scaffold(
          backgroundColor: RyuColors.void_,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Dynamic ambient background derived from album artwork
              AnimatedContainer(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      palette.primary.withValues(alpha: 0.55),
                      palette.secondary.withValues(alpha: 0.36),
                      RyuColors.void_,
                    ],
                    stops: const [0.0, 0.48, 1.0],
                  ),
                ),
              ),
              // Subtle blurred artwork texture for depth
              Positioned.fill(
                child: Opacity(
                  opacity: _tab == _PlayerTab.lyrics ? 0.28 : 0.16,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 46, sigmaY: 46),
                    child: ArtworkImage(
                      songId: song.id,
                      albumId: song.albumId,
                      size: 400,
                      borderRadius: 0,
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.55),
                      RyuColors.void_.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context, song),
                    const SizedBox(height: 8),
                    _buildModeSwitcher(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: switch (_tab) {
                          _PlayerTab.player =>
                            _buildPlayerBody(context, scope, song, isFav),
                          _PlayerTab.lyrics => const LyricsView(),
                          _PlayerTab.queue => const QueueView(),
                        },
                      ),
                    ),
                    if (_tab != _PlayerTab.player)
                      _buildCompactTransportBar(scope.audio),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, Song song) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'NOW PLAYING',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  song.album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => SongOptionsSheet.show(context, song),
            icon: const Icon(
              Icons.more_horiz_rounded,
              size: 26,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return GlassContainer(
      borderRadius: 22,
      blur: 18,
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tab in _PlayerTab.values)
            GestureDetector(
              onTap: () => setState(() => _tab = tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: _tab == tab
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.transparent,
                ),
                child: Text(
                  tab.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _tab == tab
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerBody(
    BuildContext context,
    RyuScope scope,
    Song song,
    bool isFav,
  ) {
    final audio = scope.audio;
    final palette = audio.ambientPalette;
    final screenWidth = MediaQuery.of(context).size.width;
    final artSize = (screenWidth - 64).clamp(220.0, 340.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Large artwork with breathing scale animation & ambient shadow
          AnimatedScale(
            scale: audio.isPlaying ? 1.0 : 0.92,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.45),
                    blurRadius: 42,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Hero(
                tag: 'now_playing_art',
                child: ArtworkImage(
                  songId: song.id,
                  albumId: song.albumId,
                  size: artSize,
                  borderRadius: 28,
                  iconSize: 72,
                ),
              ),
            ),
          ),

          // Title, artist, favorite & lyrics shortcut
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _tab = _PlayerTab.lyrics),
                tooltip: 'Synced Lyrics',
                icon: Icon(
                  Icons.lyrics_outlined,
                  color: audio.currentLyrics != null
                      ? palette.primary
                      : Colors.white.withValues(alpha: 0.7),
                ),
              ),
              IconButton(
                onPressed: () => scope.library.toggleFavorite(song.id),
                icon: Icon(
                  isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 28,
                  color: isFav ? RyuColors.violet : Colors.white,
                ),
              ),
            ],
          ),

          // Interactive Seek Bar
          _buildSeekBar(audio, palette.primary),

          // Full Transport Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: audio.toggleShuffle,
                icon: Icon(
                  Icons.shuffle_rounded,
                  size: 24,
                  color: audio.shuffleEnabled
                      ? RyuColors.violet
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
              IconButton(
                onPressed: audio.seekToPrevious,
                icon: const Icon(
                  Icons.skip_previous_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: audio.togglePlayPause,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RyuColors.accent,
                    boxShadow: [
                      BoxShadow(
                        color: RyuColors.violet.withValues(alpha: 0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    audio.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                onPressed: audio.seekToNext,
                icon: const Icon(
                  Icons.skip_next_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: audio.cycleRepeatMode,
                icon: Icon(
                  audio.repeatMode == RyuRepeatMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  size: 24,
                  color: audio.repeatMode != RyuRepeatMode.off
                      ? RyuColors.violet
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeekBar(AudioController audio, Color accentColor) {
    return StreamBuilder<Duration>(
      stream: audio.positionStream,
      initialData: audio.position,
      builder: (context, snapshot) {
        final total = audio.duration;
        final totalMs = total.inMilliseconds.toDouble();
        final currentPos = snapshot.data ?? audio.position;
        final currentMs = _dragSeekValue ??
            currentPos.inMilliseconds
                .toDouble()
                .clamp(0.0, totalMs > 0 ? totalMs : 1.0);

        final displayPos = Duration(milliseconds: currentMs.round());

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: totalMs > 0 ? currentMs.clamp(0.0, totalMs) : 0.0,
                min: 0.0,
                max: totalMs > 0 ? totalMs : 1.0,
                onChanged: (v) => setState(() => _dragSeekValue = v),
                onChangeEnd: (v) {
                  setState(() => _dragSeekValue = null);
                  audio.seek(Duration(milliseconds: v.round()));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DurationFormatter.format(displayPos),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  Text(
                    DurationFormatter.format(total),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactTransportBar(AudioController audio) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: GlassContainer(
        borderRadius: 24,
        blur: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              onPressed: audio.toggleShuffle,
              icon: Icon(
                Icons.shuffle_rounded,
                size: 20,
                color: audio.shuffleEnabled
                    ? RyuColors.violet
                    : Colors.white.withValues(alpha: 0.65),
              ),
            ),
            IconButton(
              onPressed: audio.seekToPrevious,
              icon: const Icon(
                Icons.skip_previous_rounded,
                size: 30,
                color: Colors.white,
              ),
            ),
            GestureDetector(
              onTap: audio.togglePlayPause,
              child: Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RyuColors.accent,
                ),
                child: Icon(
                  audio.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 30,
                  color: Colors.white,
                ),
              ),
            ),
            IconButton(
              onPressed: audio.seekToNext,
              icon: const Icon(
                Icons.skip_next_rounded,
                size: 30,
                color: Colors.white,
              ),
            ),
            IconButton(
              onPressed: audio.cycleRepeatMode,
              icon: Icon(
                audio.repeatMode == RyuRepeatMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                size: 20,
                color: audio.repeatMode != RyuRepeatMode.off
                    ? RyuColors.violet
                    : Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
