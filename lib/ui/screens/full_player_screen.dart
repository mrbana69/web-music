import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import '../../providers/player_state.dart';
import '../../providers/library_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import 'lyrics_view.dart';
import 'queue_view.dart';

class FullPlayerScreen extends StatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  int _activeSheetIndex = 0; // 0 = Player, 1 = Lyrics, 2 = Queue

  String _formatDuration(Duration d) {
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '${min.toString().padLeft(1, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final track = player.currentTrack;

    if (track == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: Text('Nessun brano in riproduzione')),
      );
    }

    final library = context.watch<LibraryState>();
    final isLiked = library.isLiked(track.id);

    final currentSeconds = player.position.inSeconds.toDouble();
    final maxSeconds = player.duration.inSeconds > 0
        ? player.duration.inSeconds.toDouble()
        : (track.durationMs / 1000).toDouble();

    final remaining = Duration(seconds: (maxSeconds - currentSeconds).clamp(0, 999999).toInt());

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          children: [
            // 1. Glowing Dynamic Ambient Background
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.4),
                    radius: 1.2,
                    colors: [
                      player.ambientColor.withOpacity(0.55),
                      player.ambientColor.withOpacity(0.18),
                      AppTheme.background,
                    ],
                  ),
                ),
              ),
            ),

            // 2. Blur Backdrop Layer
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.black.withOpacity(0.35)),
              ),
            ),

            // 3. Main Content
            SafeArea(
              child: Column(
                children: [
                  // --- Header Bar ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 34),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Column(
                          children: [
                            Text(
                              'IN RIPRODUZIONE DA',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.albumName.isNotEmpty ? track.albumName : 'Preluded Music',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 28),
                          onPressed: () => _showTrackOptions(context, track),
                        ),
                      ],
                    ),
                  ),

                  // --- Body: Player, Lyrics, or Queue ---
                  Expanded(
                    child: _activeSheetIndex == 1
                        ? const LyricsView()
                        : (_activeSheetIndex == 2 ? const QueueView() : _buildPlayerBody(context, player, track, isLiked, currentSeconds, maxSeconds, remaining)),
                  ),

                  // --- Bottom Floating Glass Action Bar ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: GlassContainer(
                      borderRadius: 30,
                      blur: 24,
                      color: Colors.white.withOpacity(0.08),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildBottomActionItem(
                            icon: Icons.lyrics_rounded,
                            label: 'Testi',
                            isSelected: _activeSheetIndex == 1,
                            onTap: () => setState(() => _activeSheetIndex = _activeSheetIndex == 1 ? 0 : 1),
                          ),
                          _buildBottomActionItem(
                            icon: Icons.queue_music_rounded,
                            label: 'Coda',
                            isSelected: _activeSheetIndex == 2,
                            onTap: () => setState(() => _activeSheetIndex = _activeSheetIndex == 2 ? 0 : 2),
                          ),
                          _buildBottomActionItem(
                            icon: Icons.airplay_rounded,
                            label: 'AirPlay',
                            isSelected: false,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerBody(
    BuildContext context,
    PlayerState player,
    dynamic track,
    bool isLiked,
    double currentSeconds,
    double maxSeconds,
    Duration remaining,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // 1. Large Artwork with 3D Drop Shadow & Horizontal Swipe
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! < -300) {
                  player.nextTrack();
                } else if (details.primaryVelocity! > 300) {
                  player.previousTrack();
                }
              }
            },
            child: Hero(
              tag: 'mini_artwork_${track.id}',
              child: Container(
                width: MediaQuery.of(context).size.width * 0.78,
                height: MediaQuery.of(context).size.width * 0.78,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: player.ambientColor.withOpacity(0.45),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                      spreadRadius: -4,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CachedNetworkImage(
                    imageUrl: track.coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(color: AppTheme.surface),
                    errorWidget: (c, u, e) => Container(
                      color: AppTheme.surface,
                      child: const Icon(Icons.music_note, color: AppTheme.textSecondary, size: 64),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // 2. Track Title, Artist, & Favorite Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.68),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isLiked ? AppTheme.primaryAccent : Colors.white.withOpacity(0.7),
                  size: 28,
                ),
                onPressed: () => context.read<LibraryState>().toggleLike(track),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3. Scrubber Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.18),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: currentSeconds.clamp(0.0, maxSeconds > 0 ? maxSeconds : 1.0),
              max: maxSeconds > 0 ? maxSeconds : 1.0,
              onChanged: (val) => player.seek(Duration(seconds: val.toInt())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(player.position),
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Text(
                  '-${_formatDuration(remaining)}',
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Main Controls Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Shuffle
              IconButton(
                icon: Icon(
                  Icons.shuffle_rounded,
                  color: player.isShuffle ? AppTheme.primaryAccent : Colors.white.withOpacity(0.6),
                  size: 24,
                ),
                onPressed: player.toggleShuffle,
              ),

              // Previous
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 40),
                onPressed: player.previousTrack,
              ),

              // Play / Pause Gradient Circle
              GestureDetector(
                onTap: player.togglePlay,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryAccent.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: player.isBuffering
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                          ),
                        )
                      : Icon(
                          player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                ),
              ),

              // Next
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 40),
                onPressed: player.nextTrack,
              ),

              // Repeat
              IconButton(
                icon: Icon(
                  player.loopMode == LoopMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  color: player.loopMode != LoopMode.off ? AppTheme.primaryAccent : Colors.white.withOpacity(0.6),
                  size: 24,
                ),
                onPressed: player.cycleRepeat,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white.withOpacity(0.7), size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTrackOptions(BuildContext context, dynamic track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Colors.white),
              title: const Text('Condividi brano', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Share.share('Ascolta ${track.title} di ${track.artistName} su Preluded!');
              },
            ),
          ],
        ),
      ),
    );
  }
}
