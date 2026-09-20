import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/album.dart';
import '../../models/artist.dart';
import '../../models/track.dart';
import '../../providers/player_state.dart';
import '../../providers/library_state.dart';
import '../../services/api_service.dart';
import '../../config/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/stitch_track_row.dart';
import 'artist_screen.dart';

class AlbumScreen extends StatefulWidget {
  final Album album;
  const AlbumScreen({super.key, required this.album});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  late Album _album;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _album = widget.album;
    _patchAlbumTrackCovers();
    if (_album.tracks.isEmpty) {
      _loadAlbum();
    }
  }

  void _patchAlbumTrackCovers() {
    final validAlbumCover = _album.coverUrl.isNotEmpty && !_album.coverUrl.contains('resources.tidal.com')
        ? _album.coverUrl
        : '';
    final patchedTracks = _album.tracks.map((t) {
      final tCover = t.coverUrl;
      final hasRealCover = tCover.isNotEmpty && !tCover.contains('resources.tidal.com');
      final effectiveCover = hasRealCover
          ? tCover
          : (validAlbumCover.isNotEmpty ? validAlbumCover : t.effectiveCoverUrl);
      return t.copyWith(
        coverUrl: effectiveCover,
        albumName: _album.title.isNotEmpty ? _album.title : t.albumName,
        albumId: _album.id.isNotEmpty ? _album.id : t.albumId,
      );
    }).toList();
    _album = _album.copyWith(tracks: patchedTracks);
  }

  Future<void> _loadAlbum() async {
    setState(() => _isLoading = true);
    try {
      final api = context.read<ApiService>();
      var fullAlbum = await api.fetchAlbum(_album.id);
      if (fullAlbum == null && _album.title.isNotEmpty && _album.title != 'Album') {
        fullAlbum = await api.fetchAlbum(_album.title);
      }
      if (fullAlbum != null && mounted) {
        final albumCover = (fullAlbum.coverUrl.isNotEmpty && !fullAlbum.coverUrl.contains('resources.tidal.com'))
            ? fullAlbum.coverUrl
            : (_album.coverUrl.isNotEmpty && !_album.coverUrl.contains('resources.tidal.com')
                ? _album.coverUrl
                : '');

        final updatedTracks = fullAlbum.tracks.map((t) {
          final tCover = t.coverUrl;
          final hasRealCover = tCover.isNotEmpty && !tCover.contains('resources.tidal.com');
          final effectiveCover = hasRealCover
              ? tCover
              : (albumCover.isNotEmpty ? albumCover : t.effectiveCoverUrl);
          return t.copyWith(
            coverUrl: effectiveCover,
            albumName: _album.title.isNotEmpty ? _album.title : t.albumName,
            albumId: _album.id.isNotEmpty ? _album.id : t.albumId,
          );
        }).toList();

        setState(() {
          _album = fullAlbum!.copyWith(
            coverUrl: albumCover.isNotEmpty ? albumCover : (updatedTracks.isNotEmpty ? updatedTracks.first.coverUrl : _album.coverUrl),
            artistName: (fullAlbum.artistName.isNotEmpty && fullAlbum.artistName != 'Artista')
                ? fullAlbum.artistName
                : _album.artistName,
            artistId: fullAlbum.artistId.isNotEmpty ? fullAlbum.artistId : _album.artistId,
            tracks: updatedTracks,
          );
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  String _formatTotalDuration() {
    if (_album.tracks.isEmpty) return '';
    final totalSeconds = _album.tracks.fold<int>(0, (sum, t) => sum + (t.durationMs ~/ 1000));
    final minutes = totalSeconds ~/ 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remMin = minutes % 60;
      return '$hours h $remMin min';
    }
    return '$minutes min';
  }

  void _shareAlbum() {
    final shareUrl = AppConfig.getShareUrl(_album.id);
    Share.share('Ascolta l\'album ${_album.title} di ${_album.artistName} su Preluded: $shareUrl');
  }

  void _openArtistPage() {
    if (_album.artistName.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistScreen(
          artist: Artist(
            id: _album.artistId,
            name: _album.artistName,
            picture: _album.coverUrl,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final library = context.watch<LibraryState>();
    final isSaved = library.isAlbumSaved(_album.id);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFF131317),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Frosted App Bar
          SliverAppBar(
            backgroundColor: const Color(0xFF131317).withOpacity(0.85),
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 17),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              _album.title,
              style: AppTheme.syne(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: const Icon(Icons.share_rounded, color: Colors.white, size: 17),
                ),
                tooltip: 'Condividi Album',
                onPressed: _shareAlbum,
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Immersive Ambient Hero Section
          SliverToBoxAdapter(
            child: _buildImmersiveHero(context, isDesktop, isSaved, library, player),
          ),

          // Tracks Header
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(isDesktop ? 28 : 16, 20, isDesktop ? 28 : 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Tracce',
                        style: AppTheme.syne(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFA2D48).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFA2D48).withOpacity(0.3)),
                        ),
                        child: Text(
                          '${_album.tracks.length}',
                          style: AppTheme.syne(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFFF525E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_album.tracks.isNotEmpty)
                    Text(
                      _formatTotalDuration(),
                      style: AppTheme.inter(color: Colors.white38, fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                ],
              ),
            ),
          ),

          // Tracks List
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFFFA2D48)))),
            )
          else if (_album.tracks.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1F),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'Nessun brano disponibile per questo album',
                    style: AppTheme.inter(color: Colors.white60, fontSize: 13),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final track = _album.tracks[i];
                  final effectiveTrack = track.copyWith(
                    coverUrl: track.coverUrl.isNotEmpty && !track.coverUrl.contains('resources.tidal.com')
                        ? track.coverUrl
                        : (_album.coverUrl.isNotEmpty && !_album.coverUrl.contains('resources.tidal.com')
                            ? _album.coverUrl
                            : track.effectiveCoverUrl),
                    albumName: _album.title.isNotEmpty ? _album.title : track.albumName,
                  );
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 14 : 0),
                    child: StitchTrackRow(
                      track: effectiveTrack,
                      queue: _album.tracks,
                      index: i,
                      customSubtitle: track.artistName.isNotEmpty ? track.artistName : _album.artistName,
                    ),
                  );
                },
                childCount: _album.tracks.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: player.currentTrack != null
          ? SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 8, vertical: isDesktop ? 8 : 4),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: 1.0,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: const MiniPlayer(),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildImmersiveHero(
    BuildContext context,
    bool isDesktop,
    bool isSaved,
    LibraryState library,
    PlayerState player,
  ) {
    final isSingle = _album.tracks.length <= 2 ||
        _album.title.toLowerCase().contains('single') ||
        _album.title.toLowerCase().contains('singolo');
    final String typeLower = _album.type.toLowerCase();
    String releaseBadge;
    Color releaseColor;
    if (typeLower.contains('ep')) {
      releaseBadge = 'EP';
      releaseColor = const Color(0xFFFF9F0A);
    } else if (typeLower.contains('singol') || typeLower.contains('single') || isSingle) {
      releaseBadge = 'SINGOLO';
      releaseColor = const Color(0xFF30D158);
    } else {
      releaseBadge = 'ALBUM';
      releaseColor = const Color(0xFFFF525E);
    }

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E11),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Ambient Radial Glow Halos
          Positioned(
            top: -50,
            left: -30,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFA2D48).withOpacity(0.28),
                    const Color(0xFFFE6B00).withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Blurred Scrim Background
          if (_album.coverUrl.isNotEmpty)
            Positioned.fill(
              child: Opacity(
                opacity: 0.16,
                child: CachedNetworkImage(
                  imageUrl: _album.coverUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 600,
                  memCacheHeight: 600,
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0E0E11).withOpacity(0.65),
                    const Color(0xFF0E0E11).withOpacity(0.95),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Hero Content
          Padding(
            padding: EdgeInsets.all(isDesktop ? 28.0 : 18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badges Row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: releaseColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: releaseColor.withOpacity(0.35)),
                      ),
                      child: Text(
                        releaseBadge,
                        style: AppTheme.syne(
                          color: releaseColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    if (_album.year.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Text(
                          _album.year,
                          style: AppTheme.inter(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Main Identity: Cover + Title & Artist
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Album Cover with Glow
                    Container(
                      width: isDesktop ? 160 : 110,
                      height: isDesktop ? 160 : 110,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFA2D48).withOpacity(0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: CachedNetworkImage(
                          imageUrl: _album.coverUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 360,
                          memCacheHeight: 360,
                          placeholder: (c, u) => Container(color: AppTheme.surfaceContainerHighest),
                          errorWidget: (c, u, e) => Container(
                            color: AppTheme.surfaceContainerHighest,
                            child: const Icon(Icons.album_rounded, color: Colors.white38, size: 48),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),

                    // Title & Artist Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _album.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.syne(
                              color: Colors.white,
                              fontSize: isDesktop ? 34 : 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Clickable Artist Pill Chip
                          if (_album.artistName.isNotEmpty)
                            InkWell(
                              onTap: _openArtistPage,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 9,
                                      backgroundColor: AppTheme.surfaceContainerHighest,
                                      backgroundImage: _album.coverUrl.isNotEmpty ? NetworkImage(_album.coverUrl) : null,
                                      child: _album.coverUrl.isEmpty ? const Icon(Icons.person, size: 10) : null,
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      _album.artistName,
                                      style: AppTheme.inter(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),

                          // Track count & total duration
                          Text(
                            '${_album.tracks.length} brani • ${_formatTotalDuration()}',
                            style: AppTheme.inter(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Action Bar
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // CTA "Riproduci Album"
                    InkWell(
                      onTap: () {
                        if (_album.tracks.isNotEmpty) {
                          player.playTrack(_album.tracks.first, newQueue: _album.tracks, index: 0);
                        }
                      },
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFA2D48), Color(0xFFFF525E)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFA2D48).withOpacity(0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 6),
                            Text(
                              'RIPRODUCI ALBUM',
                              style: AppTheme.syne(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // "Salva in Libreria" Toggle Button
                    InkWell(
                      onTap: () => library.toggleSaveAlbum(_album.id),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        decoration: BoxDecoration(
                          color: isSaved
                              ? const Color(0xFF353438)
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: isSaved
                                ? const Color(0xFF34C759).withOpacity(0.4)
                                : Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isSaved ? const Color(0xFFFA2D48) : Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isSaved ? 'SALVATO' : 'SALVA',
                              style: AppTheme.syne(
                                color: isSaved ? const Color(0xFFFF525E) : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Shuffle Button
                    InkWell(
                      onTap: () {
                        if (_album.tracks.isNotEmpty) {
                          final shuffled = List<Track>.from(_album.tracks)..shuffle(Random());
                          player.playTrack(shuffled.first, newQueue: shuffled, index: 0);
                        }
                      },
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Center(
                          child: Icon(Icons.shuffle_rounded, color: Colors.white, size: 19),
                        ),
                      ),
                    ),

                    // Share Button
                    InkWell(
                      onTap: _shareAlbum,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Center(
                          child: Icon(Icons.share_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
