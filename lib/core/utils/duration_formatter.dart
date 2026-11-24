class DurationFormatter {
  DurationFormatter._();

  static String format(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 359999);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final secStr = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final minStr = minutes.toString().padLeft(2, '0');
      return '$hours:$minStr:$secStr';
    }
    return '$minutes:$secStr';
  }

  static String formatRemaining(Duration position, Duration total) {
    final remaining = total - position;
    if (remaining.isNegative) return '-0:00';
    return '-${format(remaining)}';
  }
}
