import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/artist.dart';
import '../../providers/player_state.dart';
import '../../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';
import 'album_screen.dart';

class ArtistScreen extends StatefulWidget {
  final Artist artist;
  const ArtistScreen({super.key, required this.artist});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  late Artist _artist;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _artist = widget.artist;
    if (_artist.topTracks.isEmpty) {
      _loadArtist();
    }
  }

  Future<void> _loadArtist() async {
    setState(() => _isLoading = true);
    try {
      final api = context.read<ApiService>();
      final fullArtist = await api.fetchArtist(_artist.id);
      if (fullArtist != null && mounted) {
        setState(() {
          _artist = fullArtist;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerState>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.surfaceContainerLowest,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _artist.name,
                style: AppTheme.syne(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: _artist.picture,
                    fit: BoxFit.cover,
                    errorWidget: (c, u, e) => Container(
                      color: AppTheme.surfaceContainerHighest,
                      child: const Icon(Icons.person_rounded, size: 64, color: AppTheme.textSecondary),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_artist.bio.isNotEmpty) ...[
                    Text(
                      _artist.bio,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.inter(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_artist.topTracks.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                            label: Text('Riproduci Brani', style: AppTheme.syne(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5)),
                            onPressed: () => player.playTrack(_artist.topTracks.first, newQueue: _artist.topTracks, index: 0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Albums / Singles horizontal carousel if available
                  if (_artist.albums.isNotEmpty) ...[
                    Text(
                      'Album & Singoli',
                      style: AppTheme.syne(fontSize: 16.5, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 165,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _artist.albums.length,
                        itemBuilder: (context, i) {
                          final album = _artist.albums[i];
                          return Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 12),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AlbumScreen(album: album)),
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: CachedNetworkImage(
                                      imageUrl: album.coverUrl,
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      placeholder: (c, u) => Container(color: AppTheme.surfaceContainerHighest),
                                      errorWidget: (c, u, e) => Container(
                                        color: AppTheme.surfaceContainerHighest,
                                        child: const Icon(Icons.album_rounded, color: AppTheme.textSecondary),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    album.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.syne(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (album.year.isNotEmpty)
                                    Text(
                                      album.year,
                                      style: AppTheme.inter(color: AppTheme.textMuted, fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  Text(
                    'Brani popolari',
                    style: AppTheme.syne(fontSize: 16.5, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryAccent),
              ),
            )
          else if (_artist.topTracks.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('Nessun brano disponibile per questo artista', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => TrackTile(track: _artist.topTracks[i], queue: _artist.topTracks, index: i, showIndex: true),
                childCount: _artist.topTracks.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}
