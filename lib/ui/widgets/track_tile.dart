import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/track.dart';
import '../../providers/player_state.dart';
import '../../providers/library_state.dart';
import '../../config/app_config.dart';
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
    final isCurrent = context.select<PlayerState, bool>(
      (p) => p.currentTrack?.id == track.id || p.currentTrack?.videoId == track.id,
    );
    final isPlaying = context.select<PlayerState, bool>(
      (p) => isCurrent && p.isPlaying,
    );
    final player = context.read<PlayerState>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: isCurrent ? AppTheme.surfaceContainerHigh.withOpacity(0.7) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap ?? () {
            if (isCurrent) {
              player.togglePlay();
            } else {
              player.playTrack(track, newQueue: queue, index: index);
            }
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: AppTheme.primaryAccent.withOpacity(0.12),
          highlightColor: AppTheme.primaryAccent.withOpacity(0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Index number if required
                if (showIndex) ...[
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: AppTheme.syne(
                        color: isCurrent ? AppTheme.primaryAccent : AppTheme.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Squircle Cover Artwork with active equalizer indicator
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryAccent.withOpacity(0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: track.effectiveCoverUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          memCacheWidth: 120,
                          memCacheHeight: 120,
                          placeholder: (c, u) => Container(
                            color: AppTheme.surfaceContainerHighest,
                          ),
                          errorWidget: (c, u, e) {
                            final vId = track.effectiveVideoId;
                            if (vId.isNotEmpty) {
                              return Image.network(
                                'https://i.ytimg.com/vi/$vId/hqdefault.jpg',
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppTheme.surfaceContainerHighest,
                                  child: const Icon(Icons.music_note_rounded, color: AppTheme.textSecondary, size: 24),
                                ),
                              );
                            }
                            return Container(
                              color: AppTheme.surfaceContainerHighest,
                              child: const Icon(Icons.music_note_rounded, color: AppTheme.textSecondary, size: 24),
                            );
                          },
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isPlaying ? Icons.equalizer_rounded : Icons.play_arrow_rounded,
                            color: AppTheme.primaryAccent,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Title (Syne) & Artist (Inter)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.syne(
                          color: isCurrent ? AppTheme.primaryAccent : AppTheme.textPrimary,
                          fontSize: 13.5,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (track.isExplicit) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'E',
                                style: AppTheme.inter(
                                  color: AppTheme.textSecondary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Expanded(
                            child: Text(
                              track.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.inter(
                                color: isCurrent ? AppTheme.textPrimary.withOpacity(0.85) : AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
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
                  style: AppTheme.inter(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),

                // Action Menu Button
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 20),
                  splashRadius: 20,
                  onPressed: () => _showOptionsBottomSheet(context, track),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptionsBottomSheet(BuildContext context, Track track) {
    final library = context.read<LibraryState>();
    final isLiked = library.isLiked(track.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Track Header Preview
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: track.coverUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          memCacheWidth: 120,
                          memCacheHeight: 120,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 20),

                // Actions List
                ListTile(
                  leading: Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isLiked ? AppTheme.primaryAccent : Colors.white,
                  ),
                  title: Text(
                    isLiked ? 'Rimuovi dai Preferiti' : 'Aggiungi ai Preferiti',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    library.toggleLike(track);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add_rounded, color: Colors.white),
                  title: const Text('Aggiungi a playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddToPlaylistDialog(context, track);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded, color: Colors.white),
                  title: const Text('Condividi brano', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Share.share('Ascolta "${track.title}" di ${track.artistName} su Preluded!\n${AppConfig.getShareUrl(track.id)}');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, Track track) {
    final library = context.read<LibraryState>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Aggiungi a Playlist',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
                const SizedBox(height: 14),
                if (library.playlists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                    child: Center(
                      child: Text(
                        'Nessuna playlist creata. Creane una dalla Libreria!',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: library.playlists.length,
                      itemBuilder: (ctx, i) {
                        final pl = library.playlists[i];
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.queue_music_rounded, color: AppTheme.primaryAccent, size: 22),
                          ),
                          title: Text(pl.title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                          subtitle: Text('${pl.tracks.length} brani', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          onTap: () {
                            library.addTrackToPlaylist(pl.id, track);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Aggiunto a "${pl.title}"'),
                                backgroundColor: AppTheme.surfaceContainerHighest,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

