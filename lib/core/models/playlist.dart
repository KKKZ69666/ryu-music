class RyuPlaylist {
  const RyuPlaylist({
    required this.id,
    required this.name,
    this.description = '',
    required this.songIds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final List<int> songIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  RyuPlaylist copyWith({
    String? name,
    String? description,
    List<int>? songIds,
    DateTime? updatedAt,
  }) {
    return RyuPlaylist(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'songIds': songIds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory RyuPlaylist.fromJson(Map<String, dynamic> json) {
    return RyuPlaylist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Playlist',
      description: json['description'] as String? ?? '',
      songIds: (json['songIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
