import 'song.dart';

class Album {
  const Album({
    required this.id,
    required this.name,
    required this.artist,
    required this.songs,
  });

  final int id;
  final String name;
  final String artist;
  final List<Song> songs;

  int get coverSongId => songs.isNotEmpty ? songs.first.id : -1;
  int get trackCount => songs.length;

  Duration get totalDuration => songs.fold(
        Duration.zero,
        (sum, s) => sum + s.duration,
      );
}
