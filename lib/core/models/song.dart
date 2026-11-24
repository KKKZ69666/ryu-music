class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.durationMs,
    required this.uri,
    this.filePath,
    this.dateAdded = 0,
    this.trackNumber = 0,
  });

  final int id;
  final String title;
  final String artist;
  final String album;
  final int albumId;
  final int durationMs;
  final String uri;
  final String? filePath;
  final int dateAdded;
  final int trackNumber;

  Duration get duration => Duration(milliseconds: durationMs);

  factory Song.fromMap(Map<dynamic, dynamic> map) {
    return Song(
      id: (map['id'] as num?)?.toInt() ?? 0,
      title: (map['title'] as String?) ?? 'Unknown Title',
      artist: (map['artist'] as String?) ?? 'Unknown Artist',
      album: (map['album'] as String?) ?? 'Unknown Album',
      albumId: (map['albumId'] as num?)?.toInt() ?? -1,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      uri: (map['uri'] as String?) ?? '',
      filePath: map['filePath'] as String?,
      dateAdded: (map['dateAdded'] as num?)?.toInt() ?? 0,
      trackNumber: (map['trackNumber'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'albumId': albumId,
        'durationMs': durationMs,
        'uri': uri,
        'filePath': filePath,
        'dateAdded': dateAdded,
        'trackNumber': trackNumber,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Song && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
