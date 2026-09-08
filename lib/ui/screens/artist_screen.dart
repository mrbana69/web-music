import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/artist.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';

class ArtistScreen extends StatelessWidget {
  final Artist artist;
  const ArtistScreen({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppTheme.background,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(artist.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              background: CachedNetworkImage(imageUrl: artist.picture, fit: BoxFit.cover),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (artist.bio.isNotEmpty) ...[
                    Text(artist.bio, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 16),
                  ],
                  const Text('Brani popolari', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ),
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
