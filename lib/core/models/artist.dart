import 'album.dart';
import 'song.dart';

class Artist {
  const Artist({
    required this.name,
    required this.songs,
    required this.albums,
  });

  final String name;
  final List<Song> songs;
  final List<Album> albums;

  int get coverSongId => songs.isNotEmpty ? songs.first.id : -1;
  int get coverAlbumId => songs.isNotEmpty ? songs.first.albumId : -1;
  int get trackCount => songs.length;
  int get albumCount => albums.length;
}
