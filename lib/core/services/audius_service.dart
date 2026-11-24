import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

/// Read-only integration with the official Audius public API.
class AudiusService {
  AudiusService._();
  static final AudiusService instance = AudiusService._();

  static const _baseUrl = 'https://api.audius.co/v1';
  final http.Client _client = http.Client();

  Future<List<Song>> searchTracks(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.parse('$_baseUrl/tracks/search').replace(
      queryParameters: {'query': trimmed, 'limit': '$limit'},
    );
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Audius returned HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected Audius response');
    }
    final rawTracks = decoded['data'];
    if (rawTracks is! List) return const [];

    return rawTracks.whereType<Map>().map((raw) {
      final track = Map<String, dynamic>.from(raw);
      final id = track['id']?.toString() ?? '';
      if (id.isEmpty) return null;
      final user = track['user'];
      final artist = user is Map ? (user['name']?.toString() ?? 'Unknown Artist') : 'Unknown Artist';
      final album = track['album']?.toString() ?? 'Audius';
      final durationSeconds = (track['duration'] as num?)?.toInt() ?? 0;

      return Song(
        id: id.hashCode & 0x7fffffff,
        title: track['title']?.toString() ?? 'Untitled',
        artist: artist,
        album: album,
        albumId: -1,
        durationMs: durationSeconds * 1000,
        uri: '$_baseUrl/tracks/$id/stream',
        filePath: null,
      );
    }).whereType<Song>().toList(growable: false);
  }

  void dispose() => _client.close();
}
