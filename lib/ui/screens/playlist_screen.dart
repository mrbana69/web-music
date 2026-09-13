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
            expandedHeight: 240,
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
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isLikedSongs
                        ? [const Color(0xFFFA2D48), const Color(0xFF7928CA).withOpacity(0.6), AppTheme.background]
                        : [AppTheme.primaryAccent, const Color(0xFFFF6B6B).withOpacity(0.5), AppTheme.background],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      isLikedSongs ? Icons.favorite_rounded : Icons.queue_music_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
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
                    subtitle,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            elevation: 4,
                            shadowColor: AppTheme.primaryAccent.withOpacity(0.4),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                          label: const Text(
                            'Riproduci',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          onPressed: tracks.isNotEmpty
                              ? () => player.playTrack(tracks.first, newQueue: tracks, index: 0)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.surfaceContainerHigh,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          icon: const Icon(Icons.shuffle_rounded, color: AppTheme.textPrimary, size: 20),
                          label: const Text(
                            'Casuale',
                            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                          ),
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
                ],
              ),
            ),
          ),
          if (tracks.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('Nessun brano in questa playlist', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
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

