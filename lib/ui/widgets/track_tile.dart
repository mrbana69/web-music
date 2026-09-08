import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/track.dart';
import '../../providers/player_state.dart';
import '../../providers/library_state.dart';
import '../theme/app_theme.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final List<Track>? queue;
  final int index;
  final bool showIndex;
  final VoidCallback? onTap;

  const TrackTile({
    super.key,
    required this.track,
    this.queue,
    this.index = 0,
    this.showIndex = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final isCurrent = player.currentTrack?.id == track.id || player.currentTrack?.videoId == track.id;
    final isPlaying = isCurrent && player.isPlaying;
    final library = context.watch<LibraryState>();

    return InkWell(
      onTap: onTap ?? () => player.playTrack(track, newQueue: queue, index: index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            // Index number if required
            if (showIndex) ...[
              SizedBox(
                width: 24,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isCurrent ? AppTheme.primaryAccent : AppTheme.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Cover Artwork with active indicator
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: track.coverUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(color: AppTheme.surface),
                    errorWidget: (c, u, e) => Container(
                      width: 48,
                      height: 48,
                      color: AppTheme.surface,
                      child: const Icon(Icons.music_note, color: AppTheme.textSecondary),
                    ),
                  ),
                ),
                if (isCurrent)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPlaying ? Icons.equalizer_rounded : Icons.play_arrow_rounded,
                        color: AppTheme.primaryAccent,
                        size: 22,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Title & Artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? AppTheme.primaryAccent : AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (track.isExplicit) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.textMuted.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('E', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          track.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Duration
            Text(
              track.formattedDuration,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(width: 4),

            // 3-dots Menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
              color: AppTheme.surfaceElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (val) {
                if (val == 'like') {
                  library.toggleLike(track);
                } else if (val == 'playlist') {
                  _showAddToPlaylistDialog(context, track);
                } else if (val == 'share') {
                  Share.share('Ascolta ${track.title} di ${track.artistName} su Preluded!');
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'like',
                  child: Row(
                    children: [
                      Icon(
                        library.isLiked(track.id) ? Icons.favorite : Icons.favorite_border,
                        color: library.isLiked(track.id) ? AppTheme.primaryAccent : Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(library.isLiked(track.id) ? 'Rimuovi dai preferiti' : 'Aggiungi ai preferiti'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'playlist',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add, color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Text('Aggiungi a playlist'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Text('Condividi brano'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, Track track) {
    final library = context.read<LibraryState>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aggiungi a Playlist',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 14),
              if (library.playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Nessuna playlist creata. Creane una dalla Libreria!', style: TextStyle(color: AppTheme.textSecondary)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: library.playlists.length,
                    itemBuilder: (ctx, i) {
                      final pl = library.playlists[i];
                      return ListTile(
                        leading: const Icon(Icons.queue_music, color: AppTheme.primaryAccent),
                        title: Text(pl.title, style: const TextStyle(color: AppTheme.textPrimary)),
                        subtitle: Text('${pl.tracks.length} brani', style: const TextStyle(color: AppTheme.textSecondary)),
                        onTap: () {
                          library.addTrackToPlaylist(pl.id, track);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Aggiunto a ${pl.title}'),
                              backgroundColor: AppTheme.surfaceElevated,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
