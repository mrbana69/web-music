import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:marquee/marquee.dart';
import '../../providers/player_state.dart';
import '../../providers/library_state.dart';
import '../theme/app_theme.dart';
import 'glass_container.dart';
import '../screens/full_player_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final track = player.currentTrack;

    if (track == null) return const SizedBox.shrink();

    final library = context.watch<LibraryState>();
    final isLiked = library.isLiked(track.id);

    final progress = player.duration.inMilliseconds > 0
        ? (player.position.inMilliseconds / player.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GlassContainer(
        borderRadius: 20,
        blur: 30,
        color: const Color(0xFF181820).withOpacity(0.88),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (ctx, anim, secAnim) => const FullPlayerScreen(),
              transitionsBuilder: (ctx, anim, secAnim, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
                return SlideTransition(position: Tween(begin: begin, end: end).animate(curved), child: child);
              },
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  // 1. Artwork with drop shadow
                  Hero(
                    tag: 'mini_artwork_${track.id}',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: track.coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (c, u) => Container(color: AppTheme.surface),
                          errorWidget: (c, u, e) => Container(
                            color: AppTheme.surface,
                            child: const Icon(Icons.music_note, color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 2. Track Title & Artist
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 20,
                          child: track.title.length > 28
                              ? Marquee(
                                  text: track.title,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  scrollAxis: Axis.horizontal,
                                  blankSpace: 30.0,
                                  velocity: 30.0,
                                  pauseAfterRound: const Duration(seconds: 2),
                                )
                              : Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Like Button
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? AppTheme.primaryAccent : AppTheme.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => library.toggleLike(track),
                    splashRadius: 20,
                  ),

                  // 4. Play / Pause Button
                  IconButton(
                    icon: player.isBuffering
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryAccent),
                          )
                        : Icon(
                            player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: AppTheme.textPrimary,
                            size: 28,
                          ),
                    onPressed: player.togglePlay,
                    splashRadius: 22,
                  ),

                  // 5. Next Button
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      color: AppTheme.textPrimary,
                      size: 24,
                    ),
                    onPressed: player.nextTrack,
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            // 6. Slim Progress Bar
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2.5,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
