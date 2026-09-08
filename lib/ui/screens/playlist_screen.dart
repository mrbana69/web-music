import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/track.dart';
import '../../providers/player_state.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';

class PlaylistScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Track> tracks;
  final String? playlistId;
  final bool isLikedSongs;

  const PlaylistScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tracks,
    this.playlistId,
    this.isLikedSongs = false,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerState>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppTheme.background,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isLikedSongs
                        ? [const Color(0xFFFA2D48).withOpacity(0.8), const Color(0xFF7928CA).withOpacity(0.4)]
                        : [AppTheme.primaryAccent.withOpacity(0.6), AppTheme.background],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isLikedSongs ? Icons.favorite_rounded : Icons.queue_music_rounded,
                    size: 72,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                      label: const Text('Riproduci', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      onPressed: tracks.isNotEmpty
                          ? () => player.playTrack(tracks.first, newQueue: tracks, index: 0)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      icon: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 20),
                      label: const Text('Casuale', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      onPressed: tracks.isNotEmpty
                          ? () {
                              final shuffled = List<Track>.from(tracks)..shuffle();
                              player.playTrack(shuffled.first, newQueue: shuffled, index: 0);
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (tracks.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('Nessun brano in questa playlist', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final track = tracks[i];
                  return TrackTile(track: track, queue: tracks, index: i, showIndex: true);
                },
                childCount: tracks.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}
