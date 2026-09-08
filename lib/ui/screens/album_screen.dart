import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/album.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';

class AlbumScreen extends StatelessWidget {
  final Album album;
  const AlbumScreen({super.key, required this.album});

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
              title: Text(album.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              background: CachedNetworkImage(imageUrl: album.coverUrl, fit: BoxFit.cover),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(album.artistName, style: const TextStyle(color: AppTheme.primaryAccent, fontSize: 16, fontWeight: FontWeight.w600)),
                  if (album.year.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Anno: ${album.year}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  ],
                  const SizedBox(height: 12),
                  const Text('Tracce', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ),
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
