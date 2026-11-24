class HistoryEntry {
  const HistoryEntry({
    required this.songId,
    required this.playedAt,
  });

  final int songId;
  final DateTime playedAt;

  Map<String, dynamic> toJson() => {
        'songId': songId,
        'playedAt': playedAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      songId: (json['songId'] as num?)?.toInt() ?? 0,
      playedAt: DateTime.tryParse(json['playedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
