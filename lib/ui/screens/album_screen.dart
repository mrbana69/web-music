import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/album.dart';
import '../../providers/player_state.dart';
import '../../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';

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
    if (_album.tracks.isEmpty) {
      _loadAlbum();
    }
  }

  Future<void> _loadAlbum() async {
    setState(() => _isLoading = true);
    try {
      final api = context.read<ApiService>();
      final fullAlbum = await api.fetchAlbum(_album.id);
      if (fullAlbum != null && mounted) {
        setState(() {
          _album = fullAlbum;
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
                _album.title,
                style: AppTheme.syne(fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.3),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: _album.coverUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    memCacheHeight: 400,
                    errorWidget: (c, u, e) => Container(
                      color: AppTheme.surfaceContainerHighest,
                      child: const Icon(Icons.album_rounded, size: 64, color: AppTheme.textSecondary),
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
                  Text(
                    _album.artistName,
                    style: AppTheme.syne(color: AppTheme.primaryAccent, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  if (_album.year.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Anno: ${_album.year}', style: AppTheme.inter(color: AppTheme.textMuted, fontSize: 13)),
                  ],
                  if (_album.tracks.isNotEmpty) ...[
                    const SizedBox(height: 16),
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
                            label: Text('Riproduci Album', style: AppTheme.syne(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5)),
                            onPressed: () => player.playTrack(_album.tracks.first, newQueue: _album.tracks, index: 0),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Tracce',
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
          else if (_album.tracks.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('Nessun brano disponibile per questo album', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => TrackTile(track: _album.tracks[i], queue: _album.tracks, index: i, showIndex: true),
                childCount: _album.tracks.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}
