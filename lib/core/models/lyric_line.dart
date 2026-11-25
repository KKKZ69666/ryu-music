enum LyricsSource {
  sidecarLrc('Local .lrc file'),
  embeddedTag('Embedded audio tag'),
  importedFile('Imported .lrc file'),
  manualInput('Custom lyrics'),
  lrclibOnline('LRCLIB community database');

  const LyricsSource(this.label);
  final String label;
}

class LyricLine {
  const LyricLine({
    this.timestamp,
    required this.text,
  });

  final Duration? timestamp;
  final String text;

  bool get isSynced => timestamp != null;
}

class LyricsDocument {
  const LyricsDocument({
    required this.lines,
    required this.source,
    required this.rawText,
  });

  final List<LyricLine> lines;
  final LyricsSource source;
  final String rawText;

  bool get isSynced => lines.any((l) => l.isSynced);
  bool get isEmpty => lines.isEmpty;
}
