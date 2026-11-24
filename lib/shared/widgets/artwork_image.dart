import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/services/artwork_service.dart';
import '../../core/theme/ryu_colors.dart';

class ArtworkImage extends StatefulWidget {
  const ArtworkImage({
    super.key,
    required this.songId,
    required this.albumId,
    this.size = 52,
    this.borderRadius = 14,
    this.iconSize = 24,
  });

  final int songId;
  final int albumId;
  final double size;
  final double borderRadius;
  final double iconSize;

  @override
  State<ArtworkImage> createState() => _ArtworkImageState();
}

class _ArtworkImageState extends State<ArtworkImage> {
  Uint8List? _bytes;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ArtworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId ||
        oldWidget.albumId != widget.albumId) {
      _bytes = null;
      _resolved = false;
      _load();
    }
  }

  void _load() {
    if (widget.songId < 0 && widget.albumId < 0) {
      _resolved = true;
      return;
    }

    final cached = ArtworkService.instance.getCachedBytes(
      widget.songId,
      widget.albumId,
    );
    if (cached != null) {
      _bytes = cached;
      _resolved = true;
      return;
    }

    ArtworkService.instance
        .getArtworkBytes(widget.songId, widget.albumId)
        .then((bytes) {
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _resolved = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: _bytes != null && _bytes!.isNotEmpty
            ? Image.memory(
                _bytes!,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _PlaceholderArt(
                  iconSize: widget.iconSize,
                  dimmed: _resolved,
                ),
              )
            : _PlaceholderArt(
                iconSize: widget.iconSize,
                dimmed: _resolved,
              ),
      ),
    );
  }
}

class _PlaceholderArt extends StatelessWidget {
  const _PlaceholderArt({required this.iconSize, required this.dimmed});
  final double iconSize;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            RyuColors.violet.withValues(alpha: dimmed ? 0.24 : 0.16),
            RyuColors.indigo.withValues(alpha: dimmed ? 0.18 : 0.12),
            RyuColors.surfaceHigh,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: iconSize,
          color: RyuColors.textSecondary.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}
