import '../models/lyric_line.dart';

class LrcParser {
  LrcParser._();

  static final RegExp _timestampRegex = RegExp(
    r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]',
  );
  static final RegExp _metadataRegex =
      RegExp(r'^\[(ar|ti|al|au|by|length|re|ve):.*\]$', caseSensitive: false);
  static final RegExp _offsetRegex =
      RegExp(r'^\[offset:\s*([+-]?\d+)\s*\]$', caseSensitive: false);

  /// Parses standard LRC synced lyrics or falls back cleanly to plain lines.
  static List<LyricLine> parse(String raw) {
    final normalized = raw
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (normalized.isEmpty) return const [];

    int offsetMs = 0;
    final parsed = <LyricLine>[];
    final plainLines = <LyricLine>[];

    for (final rawLine in normalized.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final offsetMatch = _offsetRegex.firstMatch(line);
      if (offsetMatch != null) {
        offsetMs = int.tryParse(offsetMatch.group(1) ?? '0') ?? 0;
        continue;
      }

      if (_metadataRegex.hasMatch(line)) {
        continue;
      }

      final matches = _timestampRegex.allMatches(line).toList();
      if (matches.isEmpty) {
        plainLines.add(LyricLine(text: line));
        continue;
      }

      final lyricText = line.replaceAll(_timestampRegex, '').trim();
      final displayText = lyricText.isEmpty ? '• • •' : lyricText;

      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final fracStr = match.group(3) ?? '0';
        int millis = 0;
        if (fracStr.length == 1) {
          millis = (int.tryParse(fracStr) ?? 0) * 100;
        } else if (fracStr.length == 2) {
          millis = (int.tryParse(fracStr) ?? 0) * 10;
        } else {
          millis = int.tryParse(fracStr.substring(0, 3)) ?? 0;
        }

        final totalMs =
            (minutes * 60 * 1000) + (seconds * 1000) + millis - offsetMs;
        parsed.add(
          LyricLine(
            timestamp: Duration(milliseconds: totalMs < 0 ? 0 : totalMs),
            text: displayText,
          ),
        );
      }
    }

    if (parsed.isNotEmpty) {
      parsed.sort((a, b) => a.timestamp!.compareTo(b.timestamp!));
      return parsed;
    }

    return plainLines;
  }

  /// Binary search for the active lyric line index at [position].
  static int findActiveIndex(List<LyricLine> lines, Duration position) {
    if (lines.isEmpty) return -1;
    int low = 0;
    int high = lines.length - 1;
    int best = -1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final ts = lines[mid].timestamp;
      if (ts == null) {
        low = mid + 1;
        continue;
      }
      if (ts <= position) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return best;
  }
}
