import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/artist.dart';
import '../../providers/player_state.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';

class ArtistScreen extends StatelessWidget {
  final Artist artist;
  const ArtistScreen({super.key, required this.artist});

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
                artist.name,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: artist.picture,
                    fit: BoxFit.cover,
                    errorWidget: (c, u, e) => Container(
                      color: AppTheme.surfaceContainerHighest,
                      child: const Icon(Icons.person_rounded, size: 64, color: AppTheme.textSecondary),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
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
                  if (artist.bio.isNotEmpty) ...[
                    Text(
                      artist.bio,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (artist.topTracks.isNotEmpty) ...[
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
                            label: const Text('Riproduci Brani', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: () => player.playTrack(artist.topTracks.first, newQueue: artist.topTracks, index: 0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Text(
                    'Brani popolari',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
                  ),
                ],
              ),
            ),
          ),
          if (artist.topTracks.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('Nessun brano disponibile per questo artista', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => TrackTile(track: artist.topTracks[i], queue: artist.topTracks, index: i, showIndex: true),
                childCount: artist.topTracks.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

