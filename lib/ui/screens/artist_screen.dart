import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/artist.dart';
import '../../models/album.dart';
import '../../models/track.dart';
import '../../models/playlist.dart';
import '../../providers/player_state.dart';
import '../../providers/library_state.dart';
import '../../services/api_service.dart';
import '../../config/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/stitch_track_row.dart';
import 'album_screen.dart';
import 'playlist_screen.dart';

class ArtistScreen extends StatefulWidget {
  final Artist artist;
  const ArtistScreen({super.key, required this.artist});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  late Artist _artist;
  bool _isLoading = false;
  bool _showAllTracks = false;
  String _selectedDiscographyFilter = 'all'; // 'all', 'albums', 'singles'

  @override
  void initState() {
    super.initState();
    _artist = widget.artist;
    if (_artist.topTracks.isEmpty || _artist.albums.isEmpty) {
      _loadArtist();
    }
  }

  Future<void> _loadArtist() async {
    setState(() => _isLoading = true);
    try {
      final api = context.read<ApiService>();
      var fullArtist = await api.fetchArtist(_artist.id);
      if (fullArtist == null && _artist.name.isNotEmpty && _artist.name != 'Artista') {
        fullArtist = await api.fetchArtist(_artist.name);
      }
      if (fullArtist != null && mounted) {
        setState(() {
          _artist = fullArtist!;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  List<dynamic> get _filteredDiscography {
    final albums = _artist.albums;
    final singles = _artist.singles;
    final playlists = _artist.playlists;

    if (_selectedDiscographyFilter == 'albums') {
      return albums;
    } else if (_selectedDiscographyFilter == 'singles') {
      return singles;
    } else if (_selectedDiscographyFilter == 'playlists') {
      return playlists;
    }
    return [...albums, ...singles, ...playlists];
  }

  void _shareArtist() {
    final shareUrl = AppConfig.getShareUrl(_artist.id);
    Share.share('Ascolta ${_artist.name} su Preluded: $shareUrl');
  }

  void _showBioDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: _artist.picture.isNotEmpty ? NetworkImage(_artist.picture) : null,
              child: _artist.picture.isEmpty ? const Icon(Icons.person_rounded) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _artist.name,
                style: AppTheme.syne(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            _artist.bio.isNotEmpty
                ? _artist.bio
                : 'Scopri i brani più popolari e la discografia completa di ${_artist.name} su Preluded.',
            style: AppTheme.inter(color: Colors.white70, fontSize: 14, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Chiudi', style: AppTheme.syne(color: const Color(0xFFFF525E), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final library = context.watch<LibraryState>();
    final isFollowing = library.isArtistFollowed(_artist.id);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    final displayedTracks = _showAllTracks
        ? _artist.topTracks
        : _artist.topTracks.take(5).toList();

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
              _artist.name,
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
                tooltip: 'Condividi Artista',
                onPressed: _shareArtist,
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Immersive Ambient Hero Section
          SliverToBoxAdapter(
            child: _buildImmersiveHero(context, isDesktop, isFollowing, library, player),
          ),

          // Main Stage: Responsive Desktop (60/40) or Mobile Stack
          if (isDesktop) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column (60%): Popolari & Acoustic Signature
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPopularHeader(displayedTracks.length),
                          const SizedBox(height: 8),
                          if (_isLoading)
                            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFFFA2D48))))
                          else if (_artist.topTracks.isEmpty)
                            _buildEmptyTracksNotice()
                          else
                            ...displayedTracks.asMap().entries.map((e) {
                              return StitchTrackRow(
                                track: e.value,
                                queue: _artist.topTracks,
                                index: e.key,
                                showTopBadge: e.key == 0,
                                customSubtitle: e.value.albumName.isNotEmpty ? e.value.albumName : 'Singolo',
                              );
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),

                    // Right Column (40%): Tour / Highlight Card & About Info
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_artist.name.toUpperCase().contains('BLANCO')) ...[
                            _buildTourDatesCard(),
                            const SizedBox(height: 20),
                            _buildExclusiveVinylCard(),
                            const SizedBox(height: 20),
                          ],
                          _buildBiographyCard(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Mobile Vertical Flow
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: _buildPopularHeader(displayedTracks.length),
              ),
            ),
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFFFA2D48)))),
              )
            else if (_artist.topTracks.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyTracksNotice())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => StitchTrackRow(
                    track: displayedTracks[i],
                    queue: _artist.topTracks,
                    index: i,
                    showTopBadge: i == 0,
                    customSubtitle: displayedTracks[i].albumName.isNotEmpty ? displayedTracks[i].albumName : 'Singolo',
                  ),
                  childCount: displayedTracks.length,
                ),
              ),

            // Discography Carousel for Mobile
            if (_artist.albums.isNotEmpty || _artist.singles.isNotEmpty || _artist.playlists.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildMobileDiscographySection(),
              ),

            // Bio / Info Card for Mobile
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: _buildBiographyCard(),
              ),
            ),
          ],

          // Discography Grid for Desktop
          if (isDesktop && (_artist.albums.isNotEmpty || _artist.singles.isNotEmpty || _artist.playlists.isNotEmpty))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                child: _buildDesktopDiscographyGrid(),
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

  // --- Hero Section ---
  Widget _buildImmersiveHero(
    BuildContext context,
    bool isDesktop,
    bool isFollowing,
    LibraryState library,
    PlayerState player,
  ) {
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
            top: -60,
            left: -40,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFA2D48).withOpacity(0.28),
                    const Color(0xFFFE6B00).withOpacity(0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF525E).withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Blurred Scrim Background Layer
          if (_artist.picture.isNotEmpty)
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: CachedNetworkImage(
                  imageUrl: _artist.picture,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
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
                    const Color(0xFF0E0E11).withOpacity(0.6),
                    const Color(0xFF0E0E11).withOpacity(0.92),
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
                // Top Metadata Badges Row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Verified Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFFFF525E), size: 14),
                          const SizedBox(width: 5),
                          Text(
                            'ARTISTA VERIFICATO',
                            style: AppTheme.syne(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Listeners Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF34C759),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isDesktop ? '#42 NEL MONDO • 3.045.864 ASCOLTATORI' : '3.0M ASCOLTATORI',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.inter(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  ],
                ),
                const SizedBox(height: 22),

                // Main Identity Row: Concentric Glowing Avatar + Typographic Masthead
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Concentric Radial Acoustic Avatar
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Glow Ring
                        Container(
                          width: isDesktop ? 144 : 108,
                          height: isDesktop ? 144 : 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFA2D48), Color(0xFFFE6B00), Color(0xFFFF525E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFA2D48).withOpacity(0.45),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        // Inner Image Avatar
                        Container(
                          width: isDesktop ? 136 : 102,
                          height: isDesktop ? 136 : 102,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF131317),
                          ),
                          child: ClipOval(
                            child: SizedBox(
                              width: isDesktop ? 136 : 102,
                              height: isDesktop ? 136 : 102,
                              child: CachedNetworkImage(
                                imageUrl: _artist.picture,
                                width: isDesktop ? 136 : 102,
                                height: isDesktop ? 136 : 102,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                memCacheWidth: 400,
                                memCacheHeight: 400,
                                placeholder: (c, u) => Container(color: AppTheme.surfaceContainerHighest),
                                errorWidget: (c, u, e) => Container(
                                  color: AppTheme.surfaceContainerHighest,
                                  child: const Icon(Icons.person_rounded, color: Colors.white54, size: 40),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Small Bottom-Right Spatial Audio Badge
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF131317),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.15)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.spatial_audio_rounded, color: Color(0xFFFF525E), size: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 18),

                    // Typographic Masthead
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _artist.name.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.syne(
                              color: Colors.white,
                              fontSize: isDesktop ? 44 : 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              height: 1.05,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Interactive Command Action Bar
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Primary Super CTA "Riproduci"
                    InkWell(
                      onTap: () {
                        if (_artist.topTracks.isNotEmpty) {
                          player.playTrack(_artist.topTracks.first, newQueue: _artist.topTracks, index: 0);
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
                              'ASCOLTA ORA',
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

                    // "Segui" / "Seguito" Toggle Button
                    InkWell(
                      onTap: () => library.toggleFollowArtist(_artist.id),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        decoration: BoxDecoration(
                          color: isFollowing
                              ? const Color(0xFF353438)
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: isFollowing
                                ? const Color(0xFF34C759).withOpacity(0.4)
                                : Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFollowing ? Icons.check_rounded : Icons.add_rounded,
                              color: isFollowing ? const Color(0xFF34C759) : Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isFollowing ? 'SEGUITO' : 'SEGUI',
                              style: AppTheme.syne(
                                color: isFollowing ? const Color(0xFF34C759) : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // "Shuffle" Random Play Button
                    InkWell(
                      onTap: () {
                        if (_artist.topTracks.isNotEmpty) {
                          final shuffled = List<Track>.from(_artist.topTracks)..shuffle(Random());
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

                    // "Condividi" Button
                    InkWell(
                      onTap: _shareArtist,
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

  // --- Popular Section Header ---
  Widget _buildPopularHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'Popolari',
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
                _showAllTracks ? 'TUTTI' : 'TOP 5',
                style: AppTheme.syne(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFF525E),
                ),
              ),
            ),
          ],
        ),
        if (_artist.topTracks.length > 5)
          TextButton(
            onPressed: () => setState(() => _showAllTracks = !_showAllTracks),
            child: Text(
              _showAllTracks ? 'Mostra meno' : 'Mostra tutti (${_artist.topTracks.length})',
              style: AppTheme.inter(
                color: const Color(0xFFFFB3B2),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyTracksNotice() {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          'Nessun brano disponibile per questo artista',
          style: AppTheme.inter(color: Colors.white60, fontSize: 13),
        ),
      ),
    );
  }



  // --- Right Column Cards for Desktop ---
  Widget _buildTourDatesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text('IN TOUR 2025', style: AppTheme.syne(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('3 DATE SOLD OUT', style: AppTheme.inter(color: const Color(0xFFFFB3B2), fontSize: 9.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _concertRow('GIU', '14', 'Milano • Forum Assago', 'Innamorato Stadi & Arena'),
          const SizedBox(height: 10),
          _concertRow('GIU', '23', 'Roma • Stadio Olimpico', 'Special Night Acoustic + Live'),
        ],
      ),
    );
  }

  Widget _concertRow(String month, String day, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF201F23).withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF353438),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(month, style: AppTheme.syne(color: const Color(0xFFFF525E), fontSize: 9, fontWeight: FontWeight.w800)),
                Text(day, style: AppTheme.syne(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, height: 1.1)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(subtitle, style: AppTheme.inter(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Biglietti', style: AppTheme.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildExclusiveVinylCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A292E), Color(0xFF201F23), Color(0xFF0E0E11)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('EDIZIONE ESCLUSIVA PRELUDED', style: AppTheme.syne(color: const Color(0xFFFFB693), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFA2D48),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('LIMITED', style: AppTheme.syne(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Spinning Vinyl Graphic
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Center(
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFFFA2D48), Color(0xFFFE6B00)]),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Blu Celeste (Remastered)', style: AppTheme.syne(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Doppio Vinile Opaco 180g + Booklet', style: AppTheme.inter(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Artist Biography Card ---
  Widget _buildBiographyCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Informazioni',
                style: AppTheme.syne(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF34C759).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('#42 nel mondo', style: AppTheme.inter(color: const Color(0xFF34C759), fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _artist.bio.isNotEmpty
                ? _artist.bio
                : 'Scopri i brani più popolari e la discografia completa di ${_artist.name} su Preluded.',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.inter(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('12.4M', style: AppTheme.syne(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('Follower Preluded', style: AppTheme.inter(color: Colors.white38, fontSize: 11)),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showBioDialog(context),
                icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFFFFB3B2), size: 16),
                label: Text(
                  'Bio Completa',
                  style: AppTheme.inter(color: const Color(0xFFFFB3B2), fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Discography Section for Mobile (Horizontal Snap Carousel) ---
  Widget _buildMobileDiscographySection() {
    final items = _filteredDiscography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Discografia',
                style: AppTheme.syne(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _filterChip('Tutto', 'all'),
                  const SizedBox(width: 6),
                  _filterChip('Album', 'albums'),
                  const SizedBox(width: 6),
                  _filterChip('Singoli', 'singles'),
                  if (_artist.playlists.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _filterChip('Playlist', 'playlists'),
                  ],
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return _buildDiscographyCard(item, 136);
            },
          ),
        ),
      ],
    );
  }

  // --- Discography Section for Desktop (Responsive Grid) ---
  Widget _buildDesktopDiscographyGrid() {
    final items = _filteredDiscography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Discografia',
                  style: AppTheme.syne(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                _filterChip('Tutto', 'all'),
                const SizedBox(width: 8),
                _filterChip('Album', 'albums'),
                const SizedBox(width: 8),
                _filterChip('Singoli & EP', 'singles'),
                if (_artist.playlists.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _filterChip('Playlist', 'playlists'),
                ],
              ],
            ),
            Text(
              '${items.length} pubblicazioni',
              style: AppTheme.inter(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.68,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            return _buildDiscographyCard(item, double.infinity);
          },
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _selectedDiscographyFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedDiscographyFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTheme.inter(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDiscographyCard(dynamic item, double width) {
    final isAlbum = item is Album;
    final Album? album = isAlbum ? item as Album : null;
    final Playlist? playlist = !isAlbum && item is Playlist ? item as Playlist : null;

    final isSingle = isAlbum && (album!.type == 'Single' ||
        album.title.toLowerCase().contains('single') ||
        album.title.toLowerCase().contains('singolo'));
    final isEp = isAlbum && album!.type == 'EP';

    final badgeText = isAlbum
        ? (isSingle ? 'SINGOLO' : (isEp ? 'EP' : 'ALBUM'))
        : 'PLAYLIST';

    final title = isAlbum ? album!.title : (playlist?.title ?? '');
    final coverUrl = isAlbum ? album!.coverUrl : (playlist?.coverUrl ?? '');
    final subtitle = isAlbum
        ? (isSingle ? 'Singolo • ${album!.year}' : (isEp ? 'EP • ${album!.year}' : 'Album • ${album!.year}'))
        : (playlist?.subtitle.isNotEmpty ?? false ? playlist!.subtitle : 'Playlist • Preluded');

    return Container(
      width: width == double.infinity ? null : width,
      margin: width == double.infinity ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: () {
          if (isAlbum) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AlbumScreen(album: album!)),
            );
          } else if (playlist != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlaylistScreen(
                  title: playlist.title,
                  subtitle: playlist.subtitle,
                  tracks: playlist.tracks,
                  playlistId: playlist.id,
                ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Album Cover with Play Overlay & Badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 280,
                      memCacheHeight: 280,
                      placeholder: (c, u) => Container(color: AppTheme.surfaceContainerHighest),
                      errorWidget: (c, u, e) => Container(
                        color: AppTheme.surfaceContainerHighest,
                        child: Icon(isAlbum ? Icons.album_rounded : Icons.playlist_play_rounded, color: Colors.white38, size: 36),
                      ),
                    ),
                  ),
                ),
                // Release Badge at Top-Left
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0E11).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(
                      badgeText,
                      style: AppTheme.syne(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.inter(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
