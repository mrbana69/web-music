import '../config/app_config.dart';

class Track {
  final String id;
  final String videoId;
  final String title;
  final String artistName;
  final String artistId;
  final String albumName;
  final String albumId;
  final String coverUrl;
  final int durationMs;
  final String? streamUrl;
  final String source;
  final bool isExplicit;
  final bool isLiked;

  Track({
    required this.id,
    required this.videoId,
    required this.title,
    required this.artistName,
    this.artistId = '',
    this.albumName = '',
    this.albumId = '',
    required this.coverUrl,
    required this.durationMs,
    this.streamUrl,
    this.source = 'youtube',
    this.isExplicit = false,
    this.isLiked = false,
  });

  String get formattedDuration {
    final totalSec = durationMs ~/ 1000;
    final minutes = totalSec ~/ 60;
    final seconds = totalSec % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? json['videoId']?.toString() ?? '';
    final vId = json['videoId']?.toString() ?? rawId;
    final tTitle = json['title']?.toString() ?? json['name']?.toString() ?? 'Unknown Title';
    
    // Parse Artist
    String aName = 'Unknown Artist';
    String aId = '';
    if (json['artist'] != null) {
      if (json['artist'] is Map) {
        aName = json['artist']['name']?.toString() ?? '';
        aId = json['artist']['id']?.toString() ?? '';
      } else {
        aName = json['artist'].toString();
      }
    } else if (json['artists'] != null && json['artists'] is List && (json['artists'] as List).isNotEmpty) {
      final first = json['artists'][0];
      if (first is Map) {
        aName = first['name']?.toString() ?? '';
        aId = first['id']?.toString() ?? '';
      } else {
        aName = first.toString();
      }
    }
    aName = AppConfig.sanitizeArtist(aName);

    // Parse Album
    String albName = '';
    String albId = '';
    if (json['album'] != null) {
      if (json['album'] is Map) {
        albName = json['album']['title']?.toString() ?? json['album']['name']?.toString() ?? '';
        albId = json['album']['id']?.toString() ?? '';
      } else {
        albName = json['album'].toString();
      }
    }

    // Parse Cover
    String rawCover = json['cover']?.toString() ??
        json['thumbnail']?.toString() ??
        json['coverUrl']?.toString() ??
        json['picture']?.toString() ??
        (json['album'] is Map ? json['album']['cover']?.toString() : null) ??
        '';
    final cover = AppConfig.formatArtwork(rawCover);

    // Parse Duration
    int dMs = 210000;
    if (json['duration_ms'] != null) {
      dMs = int.tryParse(json['duration_ms'].toString()) ?? 210000;
    } else if (json['duration'] != null) {
      final val = json['duration'];
      if (val is int) {
        dMs = val > 1000 ? val : val * 1000;
      } else if (val is String) {
        if (val.contains(':')) {
          final parts = val.split(':').map((p) => int.tryParse(p.trim()) ?? 0).toList();
          if (parts.length == 2) dMs = (parts[0] * 60 + parts[1]) * 1000;
          if (parts.length == 3) dMs = (parts[0] * 3600 + parts[1] * 60 + parts[2]) * 1000;
        } else {
          final s = int.tryParse(val) ?? 210;
          dMs = s > 1000 ? s : s * 1000;
        }
      }
    }

    return Track(
      id: rawId,
      videoId: vId,
      title: tTitle,
      artistName: aName,
      artistId: aId,
      albumName: albName.isEmpty ? tTitle : albName,
      albumId: albId,
      coverUrl: cover,
      durationMs: dMs,
      streamUrl: json['streamUrl']?.toString() ?? json['url']?.toString(),
      source: json['source']?.toString() ?? 'youtube',
      isExplicit: json['isExplicit'] == true || json['explicit'] == true,
      isLiked: json['isLiked'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'videoId': videoId,
    'title': title,
    'artistName': artistName,
    'artistId': artistId,
    'albumName': albumName,
    'albumId': albumId,
    'coverUrl': coverUrl,
    'durationMs': durationMs,
    'streamUrl': streamUrl,
    'source': source,
    'isExplicit': isExplicit,
    'isLiked': isLiked,
  };

  Track copyWith({
    String? id,
    String? videoId,
    String? title,
    String? artistName,
    String? artistId,
    String? albumName,
    String? albumId,
    String? coverUrl,
    int? durationMs,
    String? streamUrl,
    String? source,
    bool? isExplicit,
    bool? isLiked,
  }) {
    return Track(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      artistName: artistName ?? this.artistName,
      artistId: artistId ?? this.artistId,
      albumName: albumName ?? this.albumName,
      albumId: albumId ?? this.albumId,
      coverUrl: coverUrl ?? this.coverUrl,
      durationMs: durationMs ?? this.durationMs,
      streamUrl: streamUrl ?? this.streamUrl,
      source: source ?? this.source,
      isExplicit: isExplicit ?? this.isExplicit,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
