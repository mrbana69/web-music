import 'track.dart';

class Playlist {
  final String id;
  final String title;
  final String subtitle;
  final String coverUrl;
  final List<Track> tracks;
  final DateTime createdAt;
  final bool isLocal;

  Playlist({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.coverUrl = '',
    this.tracks = const [],
    DateTime? createdAt,
    this.isLocal = true,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final tList = (json['tracks'] as List? ?? [])
        .map((t) => Track.fromJson(Map<String, dynamic>.from(t)))
        .toList();

    return Playlist(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Nuova Playlist',
      subtitle: json['subtitle']?.toString() ?? '${tList.length} brani',
      coverUrl: json['coverUrl']?.toString() ?? (tList.isNotEmpty ? tList.first.coverUrl : ''),
      tracks: tList,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isLocal: json['isLocal'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'coverUrl': coverUrl,
    'tracks': tracks.map((t) => t.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'isLocal': isLocal,
  };

  Playlist copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? coverUrl,
    List<Track>? tracks,
    DateTime? createdAt,
    bool? isLocal,
  }) {
    return Playlist(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      coverUrl: coverUrl ?? this.coverUrl,
      tracks: tracks ?? this.tracks,
      createdAt: createdAt ?? this.createdAt,
      isLocal: isLocal ?? this.isLocal,
    );
  }
}
