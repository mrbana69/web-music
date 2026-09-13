import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:marquee/marquee.dart';
import '../../providers/player_state.dart';
import '../../providers/library_state.dart';
import '../theme/app_theme.dart';
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -250) {
              player.nextTrack();
            } else if (details.primaryVelocity! > 250) {
              player.previousTrack();
            }
          }
        },
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
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: player.ambientColor.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    // 1. Squircle Artwork with Hero
                    Hero(
                      tag: 'mini_artwork_${track.id}',
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppTheme.surfaceContainerLowest,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CachedNetworkImage(
                          imageUrl: track.coverUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 120,
                          memCacheHeight: 120,
                          placeholder: (c, u) => Container(color: AppTheme.surfaceContainerLowest),
                          errorWidget: (c, u, e) => Container(
                            color: AppTheme.surfaceContainerLowest,
                            child: const Icon(Icons.music_note_rounded, color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 2. Title (Syne) & Artist (Inter)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            child: track.title.length > 26
                                ? Marquee(
                                    text: track.title,
                                    style: AppTheme.syne(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                    scrollAxis: Axis.horizontal,
                                    blankSpace: 30.0,
                                    velocity: 28.0,
                                    pauseAfterRound: const Duration(seconds: 2),
                                  )
                                : Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.syne(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. Like Button
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isLiked ? AppTheme.primaryAccent : AppTheme.textSecondary,
                        size: 22,
                      ),
                      onPressed: () => library.toggleLike(track),
                    ),

                    // 4. Material 3 Tonal Play / Pause FAB
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryAccent,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryAccent.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: player.isBuffering
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(
                                player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                        onPressed: player.togglePlay,
                      ),
                    ),
                    const SizedBox(width: 4),

                    // 5. Next Button
                    IconButton(
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: AppTheme.textPrimary,
                        size: 26,
                      ),
                      onPressed: player.nextTrack,
                    ),
                  ],
                ),
              ),

              // 6. Micro Progress Indicator
              ValueListenableBuilder<Duration>(
                valueListenable: player.positionNotifier,
                builder: (context, pos, _) {
                  final progress = player.duration.inMilliseconds > 0
                      ? (pos.inMilliseconds / player.duration.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0;
                  return LinearProgressIndicator(
                    value: progress,
                    minHeight: 2.5,
                    backgroundColor: Colors.white.withOpacity(0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(player.ambientColor),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
