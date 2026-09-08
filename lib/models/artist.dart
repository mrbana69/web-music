import '../config/app_config.dart';
import 'track.dart';
import 'album.dart';

class Artist {
  final String id;
  final String name;
  final String picture;
  final String bio;
  final List<Track> topTracks;
  final List<Album> albums;
  final List<Artist> relatedArtists;

  Artist({
    required this.id,
    required this.name,
    required this.picture,
    this.bio = '',
    this.topTracks = const [],
    this.albums = const [],
    this.relatedArtists = const [],
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    final rawPic = json['picture'] ?? json['avatar'] ?? json['thumbnail'] ?? '';
    final tracksList = (json['tracks'] as List? ?? json['topTracks'] as List? ?? [])
        .map((t) => Track.fromJson(Map<String, dynamic>.from(t)))
        .toList();
    final albumsList = (json['albums'] as List? ?? [])
        .map((a) => Album.fromJson(Map<String, dynamic>.from(a)))
        .toList();
    final relatedList = (json['similar'] as List? ?? json['related'] as List? ?? [])
        .map((r) => Artist.fromJson(Map<String, dynamic>.from(r)))
        .toList();

    return Artist(
      id: json['id']?.toString() ?? '',
      name: AppConfig.sanitizeArtist(json['name']?.toString() ?? ''),
      picture: AppConfig.formatArtwork(rawPic),
      bio: json['bio']?.toString() ?? json['description']?.toString() ?? '',
      topTracks: tracksList,
      albums: albumsList,
      relatedArtists: relatedList,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'picture': picture,
    'bio': bio,
  };
}
