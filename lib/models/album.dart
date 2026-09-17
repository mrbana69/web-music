import '../config/app_config.dart';
import 'track.dart';

class Album {
  final String id;
  final String title;
  final String artistName;
  final String artistId;
  final String coverUrl;
  final String year;
  final List<Track> tracks;

  Album({
    required this.id,
    required this.title,
    required this.artistName,
    this.artistId = '',
    required this.coverUrl,
    this.year = '',
    this.tracks = const [],
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    final rawCover = json['coverUrl'] ?? json['cover'] ?? json['thumbnail'] ?? json['picture'] ?? '';
    final trackItems = (json['tracks'] as List? ?? json['items'] as List? ?? [])
        .map((t) => Track.fromJson(Map<String, dynamic>.from(t)))
        .toList();

    return Album(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'Album',
      artistName: AppConfig.sanitizeArtist(json['artist'] ?? json['artistName'] ?? ''),
      artistId: json['artistId']?.toString() ?? '',
      coverUrl: AppConfig.formatArtwork(rawCover),
      year: json['year']?.toString() ?? json['releaseDate']?.toString() ?? '',
      tracks: trackItems,
    );
  }

  Album copyWith({
    String? id,
    String? title,
    String? artistName,
    String? artistId,
    String? coverUrl,
    String? year,
    List<Track>? tracks,
  }) {
    return Album(
      id: id ?? this.id,
      title: title ?? this.title,
      artistName: artistName ?? this.artistName,
      artistId: artistId ?? this.artistId,
      coverUrl: coverUrl ?? this.coverUrl,
      year: year ?? this.year,
      tracks: tracks ?? this.tracks,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artistName': artistName,
    'artistId': artistId,
    'coverUrl': coverUrl,
    'year': year,
  };
}
