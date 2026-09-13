import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/album.dart';
import '../../providers/player_state.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';

class AlbumScreen extends StatelessWidget {
  final Album album;
  const AlbumScreen({super.key, required this.album});

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
                album.title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: album.coverUrl,
                    fit: BoxFit.cover,
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
                    album.artistName,
                    style: const TextStyle(color: AppTheme.primaryAccent, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (album.year.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Anno: ${album.year}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  ],
                  if (album.tracks.isNotEmpty) ...[
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
                            label: const Text('Riproduci Album', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: () => player.playTrack(album.tracks.first, newQueue: album.tracks, index: 0),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text('Tracce', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
                ],
              ),
            ),
          ),
          if (album.tracks.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('Nessun brano disponibile per questo album', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => TrackTile(track: album.tracks[i], queue: album.tracks, index: i, showIndex: true),
                childCount: album.tracks.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

