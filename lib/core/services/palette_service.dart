import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/ryu_colors.dart';
import 'artwork_service.dart';

class AmbientPalette {
  const AmbientPalette({
    required this.primary,
    required this.secondary,
    required this.glow,
  });

  final Color primary;
  final Color secondary;
  final Color glow;

  static const AmbientPalette fallback = AmbientPalette(
    primary: RyuColors.violet,
    secondary: RyuColors.indigo,
    glow: RyuColors.blue,
  );
}

class PaletteService {
  PaletteService._();
  static final PaletteService instance = PaletteService._();

  final Map<String, AmbientPalette> _cache = {};

  Future<AmbientPalette> getPaletteForSong(int songId, int albumId) async {
    final key = albumId > 0 ? 'album_$albumId' : 'song_$songId';
    if (_cache.containsKey(key)) return _cache[key]!;

    final bytes = await ArtworkService.instance.getArtworkBytes(songId, albumId);
    if (bytes == null || bytes.isEmpty) {
      _cache[key] = AmbientPalette.fallback;
      return AmbientPalette.fallback;
    }

    final palette = await _extractFromBytes(bytes);
    _cache[key] = palette;
    return palette;
  }

  Future<AmbientPalette> _extractFromBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 28,
        targetHeight: 28,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      frame.image.dispose();
      codec.dispose();

      if (byteData == null) return AmbientPalette.fallback;

      final data = byteData.buffer.asUint8List();
      final buckets = <int, _ColorBucket>{};

      for (int i = 0; i + 3 < data.length; i += 4) {
        final r = data[i];
        final g = data[i + 1];
        final b = data[i + 2];
        final a = data[i + 3];
        if (a < 180) continue;

        final hsl = HSLColor.fromColor(Color.fromARGB(255, r, g, b));
        // Skip near-black and near-white pixels
        if (hsl.lightness < 0.12 || hsl.lightness > 0.88) continue;

        final hueBucket = (hsl.hue / 24).floor();
        final weight = 1.0 + (hsl.saturation * 2.5);
        final bucket = buckets.putIfAbsent(hueBucket, () => _ColorBucket());
        bucket.add(r, g, b, weight);
      }

      if (buckets.isEmpty) return AmbientPalette.fallback;

      final sorted = buckets.values.toList()
        ..sort((a, b) => b.weight.compareTo(a.weight));

      final primary = _tuneForDarkAmbient(sorted.first.toColor());
      final secondary = sorted.length > 1
          ? _tuneForDarkAmbient(sorted[1].toColor())
          : _shiftHue(primary, 28);
      final glow = _shiftHue(primary, -22);

      return AmbientPalette(
        primary: primary,
        secondary: secondary,
        glow: glow,
      );
    } catch (_) {
      return AmbientPalette.fallback;
    }
  }

  Color _tuneForDarkAmbient(Color c) {
    final hsl = HSLColor.fromColor(c);
    final sat = hsl.saturation.clamp(0.45, 0.88);
    final light = hsl.lightness.clamp(0.32, 0.54);
    return hsl.withSaturation(sat).withLightness(light).toColor();
  }

  Color _shiftHue(Color c, double delta) {
    final hsl = HSLColor.fromColor(c);
    final nextHue = (hsl.hue + delta) % 360;
    return hsl.withHue(nextHue < 0 ? nextHue + 360 : nextHue).toColor();
  }
}

class _ColorBucket {
  double r = 0;
  double g = 0;
  double b = 0;
  double weight = 0;

  void add(int red, int green, int blue, double w) {
    r += red * w;
    g += green * w;
    b += blue * w;
    weight += w;
  }

  Color toColor() {
    if (weight <= 0) return RyuColors.violet;
    return Color.fromARGB(
      255,
      (r / weight).round().clamp(0, 255),
      (g / weight).round().clamp(0, 255),
      (b / weight).round().clamp(0, 255),
    );
  }
}
