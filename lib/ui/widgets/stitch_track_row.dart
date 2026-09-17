import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/track.dart';
import '../../providers/player_state.dart';
import '../theme/app_theme.dart';
import '../screens/full_player_screen.dart';
import 'soundwave_visualizer.dart';

class StitchTrackRow extends StatelessWidget {
  final Track track;
  final List<Track> queue;
  final int index;
  final String? customSubtitle;
  final bool showTopBadge;

  const StitchTrackRow({
    super.key,
    required this.track,
    required this.queue,
    required this.index,
    this.customSubtitle,
    this.showTopBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final isCurrent = player.currentTrack?.id == track.id ||
        (track.videoId.isNotEmpty && player.currentTrack?.videoId == track.videoId);
    final isPlaying = isCurrent && player.isPlaying;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFF201F23)
            : const Color(0xFF1B1B1F).withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFFFA2D48).withOpacity(0.5)
              : Colors.white.withOpacity(0.05),
          width: isCurrent ? 1.2 : 1.0,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: const Color(0xFFFA2D48).withOpacity(0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            player.playTrack(track, newQueue: queue, index: index);
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFFFA2D48).withOpacity(0.15),
          highlightColor: const Color(0xFFFA2D48).withOpacity(0.08),
          child: Stack(
            children: [
              // Glowing accent indicator bar on the left
              if (isCurrent)
                Positioned(
                  left: 0,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    width: 3.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFA2D48),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFA2D48).withOpacity(0.8),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Index or Play Indicator
                    SizedBox(
                      width: 24,
                      child: isPlaying
                          ? const SoundwaveVisualizer(isPlaying: true, height: 14, barCount: 3)
                          : isCurrent
                              ? const Icon(Icons.play_arrow_rounded, color: Color(0xFFFF525E), size: 18)
                              : Text(
                                  '${index + 1}',
                                  textAlign: TextAlign.center,
                                  style: AppTheme.inter(
                                    color: Colors.white.withOpacity(0.35),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                    ),
                    const SizedBox(width: 10),

                    // Square Cover Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: track.coverUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 120,
                              memCacheHeight: 120,
                              placeholder: (c, u) => Container(color: AppTheme.surfaceContainerHighest),
                              errorWidget: (c, u, e) => Container(
                                color: AppTheme.surfaceContainerHighest,
                                child: const Icon(Icons.music_note_rounded, color: Colors.white38, size: 20),
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                color: Colors.black.withOpacity(0.35),
                                child: Center(
                                  child: Icon(
                                    isPlaying ? Icons.equalizer_rounded : Icons.play_arrow_rounded,
                                    color: const Color(0xFFFF525E),
                                    size: 20,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.inter(
                                    color: isCurrent ? const Color(0xFFFF525E) : Colors.white,
                                    fontSize: 14,
                                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (showTopBadge) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFA2D48).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFFA2D48).withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    'TOP',
                                    style: AppTheme.syne(
                                      color: const Color(0xFFFF525E),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                              if (track.isExplicit) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'E',
                                    style: AppTheme.inter(
                                      color: Colors.white60,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            customSubtitle ?? (track.artistName.isNotEmpty ? track.artistName : 'Preluded Hi-Fi'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.inter(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Active Soundwave Bar on the right (responsive)
                    if (isCurrent)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: SoundwaveVisualizer(
                          isPlaying: isPlaying,
                          height: 16,
                          barCount: 4,
                        ),
                      ),

                    // Duration
                    Text(
                      track.formattedDuration,
                      style: AppTheme.inter(
                        color: isCurrent ? Colors.white70 : Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // Lyrics button
                    IconButton(
                      icon: Icon(
                        Icons.lyrics_rounded,
                        color: isCurrent ? const Color(0xFFFF525E) : Colors.white38,
                        size: 18,
                      ),
                      tooltip: 'Testo brano',
                      splashRadius: 18,
                      onPressed: () {
                        if (!isCurrent) {
                          player.playTrack(track, newQueue: queue, index: index);
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FullPlayerScreen(initialTab: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
