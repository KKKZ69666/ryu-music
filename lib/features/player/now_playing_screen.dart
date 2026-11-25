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
                child: LayoutBuilder(
                  builder: (context, viewportConstraints) {
                    final isCompactHeight = viewportConstraints.maxHeight < 620;
                    return Column(
                      children: [
                        _buildTopBar(context, song, compact: isCompactHeight),
                        SizedBox(height: isCompactHeight ? 4 : 8),
                        _buildModeSwitcher(
                          maxWidth: viewportConstraints.maxWidth,
                          compact: isCompactHeight,
                        ),
                        SizedBox(height: isCompactHeight ? 4 : 8),
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
                          _buildCompactTransportBar(
                            scope.audio,
                            compact: isCompactHeight,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    Song song, {
    bool compact = false,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, compact ? 2 : 6, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: compact ? 28 : 32,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: Icon(
              Icons.more_horiz_rounded,
              size: compact ? 24 : 26,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher({
    required double maxWidth,
    bool compact = false,
  }) {
    final horizontalPad = maxWidth < 360 ? 14.0 : 18.0;
    final verticalPad = compact ? 5.0 : 7.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: GlassContainer(
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
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPad,
                      vertical: verticalPad,
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
        ),
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
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final isLandscape = maxW > maxH && maxW >= 540;
        final isNarrow = maxW < 360;
        final hPad = isNarrow ? 20.0 : 28.0;

        if (isLandscape) {
          final artSize = (maxH - 28).clamp(130.0, (maxW * 0.42).clamp(150.0, 320.0));
          return Padding(
            padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 16),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Center(
                    child: _buildArtworkCard(audio, song, palette.primary, artSize),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMetadataRow(scope, song, isFav, compact: true),
                      _buildSeekBar(audio, palette.primary, compact: true),
                      _buildTransportControls(
                        audio,
                        compact: true,
                        narrow: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final isCompactH = maxH < 510;
        final topPad = isCompactH ? 4.0 : 8.0;
        final bottomPad = isCompactH ? 10.0 : 18.0;
        final playButtonSize = isCompactH ? 58.0 : (isNarrow ? 64.0 : 72.0);
        final metadataHeight = (56.0 * textScale).clamp(52.0, 88.0);
        final seekBarHeight = (58.0 * textScale).clamp(54.0, 84.0);
        final minVerticalGaps = isCompactH ? 24.0 : 42.0;

        final reservedHeight =
            topPad + bottomPad + metadataHeight + seekBarHeight + playButtonSize + minVerticalGaps;
        final maxArtByHeight = (maxH - reservedHeight).clamp(108.0, 340.0);
        final maxArtByWidth = (maxW - (hPad * 2)).clamp(108.0, 340.0);
        final artSize = maxArtByHeight < maxArtByWidth ? maxArtByHeight : maxArtByWidth;

        return Padding(
          padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, bottomPad),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildArtworkCard(audio, song, palette.primary, artSize),
              _buildMetadataRow(scope, song, isFav, compact: isCompactH),
              _buildSeekBar(audio, palette.primary, compact: isCompactH),
              _buildTransportControls(
                audio,
                compact: isCompactH,
                narrow: isNarrow,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtworkCard(
    AudioController audio,
    Song song,
    Color glowColor,
    double artSize,
  ) {
    final radius = (artSize * 0.095).clamp(16.0, 28.0);
    final iconSize = (artSize * 0.25).clamp(36.0, 72.0);

    return AnimatedScale(
      scale: audio.isPlaying ? 1.0 : 0.93,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.45),
              blurRadius: 38,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Hero(
          tag: 'now_playing_art',
          child: ArtworkImage(
            songId: song.id,
            albumId: song.albumId,
            size: artSize,
            borderRadius: radius,
            iconSize: iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataRow(
    RyuScope scope,
    Song song,
    bool isFav, {
    bool compact = false,
  }) {
    final audio = scope.audio;
    final palette = audio.ambientPalette;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 19.5 : 22.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 13.5 : 15,
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
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: const EdgeInsets.all(6),
          icon: Icon(
            Icons.lyrics_outlined,
            size: compact ? 22 : 24,
            color: audio.currentLyrics != null
                ? palette.primary
                : Colors.white.withValues(alpha: 0.7),
          ),
        ),
        IconButton(
          onPressed: () => scope.library.toggleFavorite(song.id),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: const EdgeInsets.all(6),
          icon: Icon(
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: compact ? 25 : 28,
            color: isFav ? RyuColors.violet : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTransportControls(
    AudioController audio, {
    bool compact = false,
    bool narrow = false,
  }) {
    final playSize = compact ? 58.0 : (narrow ? 64.0 : 72.0);
    final playIconSize = compact ? 32.0 : (narrow ? 36.0 : 40.0);
    final skipIconSize = compact ? 32.0 : (narrow ? 34.0 : 38.0);
    final sideIconSize = compact ? 21.0 : 24.0;
    final btnConstraints = BoxConstraints(
      minWidth: narrow ? 38 : 44,
      minHeight: narrow ? 38 : 44,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: audio.toggleShuffle,
          constraints: btnConstraints,
          padding: EdgeInsets.zero,
          icon: Icon(
            Icons.shuffle_rounded,
            size: sideIconSize,
            color: audio.shuffleEnabled
                ? RyuColors.violet
                : Colors.white.withValues(alpha: 0.6),
          ),
        ),
        IconButton(
          onPressed: audio.seekToPrevious,
          constraints: btnConstraints,
          padding: EdgeInsets.zero,
          icon: Icon(
            Icons.skip_previous_rounded,
            size: skipIconSize,
            color: Colors.white,
          ),
        ),
        GestureDetector(
          onTap: audio.togglePlayPause,
          child: Container(
            width: playSize,
            height: playSize,
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
              size: playIconSize,
              color: Colors.white,
            ),
          ),
        ),
        IconButton(
          onPressed: audio.seekToNext,
          constraints: btnConstraints,
          padding: EdgeInsets.zero,
          icon: Icon(
            Icons.skip_next_rounded,
            size: skipIconSize,
            color: Colors.white,
          ),
        ),
        IconButton(
          onPressed: audio.cycleRepeatMode,
          constraints: btnConstraints,
          padding: EdgeInsets.zero,
          icon: Icon(
            audio.repeatMode == RyuRepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            size: sideIconSize,
            color: audio.repeatMode != RyuRepeatMode.off
                ? RyuColors.violet
                : Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildSeekBar(
    AudioController audio,
    Color accentColor, {
    bool compact = false,
  }) {
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
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: RoundSliderOverlayShape(
                  overlayRadius: compact ? 11 : 14,
                ),
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
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  Text(
                    DurationFormatter.format(total),
                    style: TextStyle(
                      fontSize: 11.5,
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

  Widget _buildCompactTransportBar(
    AudioController audio, {
    bool compact = false,
  }) {
    const btnConstraints = BoxConstraints(minWidth: 38, minHeight: 38);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, compact ? 8 : 12),
      child: GlassContainer(
        borderRadius: 24,
        blur: 20,
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 6 : 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              onPressed: audio.toggleShuffle,
              constraints: btnConstraints,
              padding: EdgeInsets.zero,
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
              constraints: btnConstraints,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.skip_previous_rounded,
                size: 28,
                color: Colors.white,
              ),
            ),
            GestureDetector(
              onTap: audio.togglePlayPause,
              child: Container(
                width: compact ? 44 : 50,
                height: compact ? 44 : 50,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RyuColors.accent,
                ),
                child: Icon(
                  audio.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: compact ? 26 : 30,
                  color: Colors.white,
                ),
              ),
            ),
            IconButton(
              onPressed: audio.seekToNext,
              constraints: btnConstraints,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.skip_next_rounded,
                size: 28,
                color: Colors.white,
              ),
            ),
            IconButton(
              onPressed: audio.cycleRepeatMode,
              constraints: btnConstraints,
              padding: EdgeInsets.zero,
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
