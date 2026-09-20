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

  String get effectiveVideoId => videoId.isNotEmpty ? videoId : id;

  String get effectiveCoverUrl {
    if (coverUrl.isNotEmpty &&
        !coverUrl.contains('resources.tidal.com') &&
        (coverUrl.startsWith('http://') || coverUrl.startsWith('https://'))) {
      return coverUrl;
    }
    final vId = effectiveVideoId;
    if (vId.isNotEmpty && vId.length >= 8) {
      return 'https://i.ytimg.com/vi/$vId/hqdefault.jpg';
    }
    return coverUrl;
  }

  String get formattedDuration {
    final totalSec = durationMs ~/ 1000;
    final minutes = totalSec ~/ 60;
    final seconds = totalSec % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? json['videoId']?.toString() ?? '';
    final vId = json['videoId']?.toString() ?? rawId;
    var tTitle = json['title']?.toString() ?? json['name']?.toString() ?? 'Unknown Title';
    
    // Parse Artist
    String aName = '';
    String aId = '';
    
    if (json['artistName'] != null && json['artistName'].toString().trim().isNotEmpty) {
      aName = json['artistName'].toString().trim();
    } else if (json['artist_name'] != null && json['artist_name'].toString().trim().isNotEmpty) {
      aName = json['artist_name'].toString().trim();
    } else if (json['artist'] != null) {
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
    } else if (json['author'] != null) {
      if (json['author'] is Map) {
        aName = json['author']['name']?.toString() ?? '';
      } else {
        aName = json['author'].toString();
      }
    }

    if (aId.isEmpty) {
      aId = json['artistId']?.toString() ?? json['artist_id']?.toString() ?? '';
    }

    // Check if artist is missing or generic
    final isGenericArtist = aName.isEmpty ||
        aName.toLowerCase() == 'unknown artist' ||
        aName.toLowerCase() == 'artista sconosciuto' ||
        aName.toLowerCase() == 'artista' ||
        aName.toLowerCase() == 'artist';

    // If generic, try extracting artist from "Artist - Song Title"
    if (isGenericArtist && tTitle.contains(' - ')) {
      final parts = tTitle.split(' - ');
      if (parts.length >= 2 && parts[0].trim().isNotEmpty) {
        aName = parts[0].trim();
        tTitle = parts.sublist(1).join(' - ').trim();
      }
    }

    if (aName.isEmpty) {
      aName = 'Unknown Artist';
    }
    aName = AppConfig.sanitizeArtist(aName);

    // Parse Album
    String albName = '';
    String albId = '';
    if (json['albumName'] != null && json['albumName'].toString().trim().isNotEmpty) {
      albName = json['albumName'].toString().trim();
    } else if (json['album_name'] != null && json['album_name'].toString().trim().isNotEmpty) {
      albName = json['album_name'].toString().trim();
    } else if (json['album'] != null) {
      if (json['album'] is Map) {
        albName = json['album']['title']?.toString() ?? json['album']['name']?.toString() ?? '';
        albId = json['album']['id']?.toString() ?? '';
      } else {
        albName = json['album'].toString();
      }
    }
    if (albId.isEmpty) {
      albId = json['albumId']?.toString() ?? json['album_id']?.toString() ?? '';
    }

    // Parse Cover
    String rawCover = json['coverUrl']?.toString() ??
        json['cover']?.toString() ??
        json['thumbnail']?.toString() ??
        json['picture']?.toString() ??
        (json['album'] is Map ? json['album']['cover']?.toString() : null) ??
        '';
    final cover = AppConfig.formatArtwork(rawCover);

    // Parse Duration
    int dMs = 210000;
    if (json['durationMs'] != null) {
      dMs = int.tryParse(json['durationMs'].toString()) ?? 210000;
    } else if (json['duration_ms'] != null) {
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
    'artist': artistName,
    'artistId': artistId,
    'albumName': albumName,
    'album': albumName,
    'albumId': albumId,
    'coverUrl': coverUrl,
    'durationMs': durationMs,
    'duration_ms': durationMs,
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
