import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import '../../providers/player_state.dart';
import '../../providers/library_state.dart';
import '../../config/app_config.dart';
import '../theme/app_theme.dart';
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

    final maxSeconds = player.duration.inSeconds > 0
        ? player.duration.inSeconds.toDouble()
        : (track.durationMs / 1000).toDouble();

    final isApple = Theme.of(context).platform == TargetPlatform.iOS || Theme.of(context).platform == TargetPlatform.macOS;

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
            // 1. Glowing Dynamic Ambient Background (Material You Tint)
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.3),
                    radius: 1.3,
                    colors: [
                      player.ambientColor.withOpacity(0.50),
                      player.ambientColor.withOpacity(0.15),
                      AppTheme.background,
                    ],
                  ),
                ),
              ),
            ),

            // 2. Blur Backdrop Layer (Apple only to avoid GPU lag on Android)
            Positioned.fill(
              child: isApple
                  ? BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                      child: Container(color: Colors.black.withOpacity(0.35)),
                    )
                  : Container(color: Colors.black.withOpacity(0.35)),
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
                        if (track.albumName.isNotEmpty)
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                track.albumName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: AppTheme.inter(
                                  color: Colors.white.withOpacity(0.70),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 24),
                          onPressed: () => _showTrackOptions(context, track),
                        ),
                      ],
                    ),
                  ),

                  // --- Body: Player, Lyrics, or Queue ---
                  Expanded(
                    child: _activeSheetIndex == 1
                        ? const LyricsView()
                        : (_activeSheetIndex == 2
                            ? const QueueView()
                            : _buildPlayerBody(context, player, track, isLiked, maxSeconds)),
                  ),

                  // --- Bottom Centered Action Icons (Lyrics, Queue, Share) ---
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildBottomIconButton(
                          icon: Icons.lyrics_rounded,
                          isSelected: _activeSheetIndex == 1,
                          ambientColor: player.ambientColor,
                          onTap: () => setState(() => _activeSheetIndex = _activeSheetIndex == 1 ? 0 : 1),
                        ),
                        const SizedBox(width: 32),
                        _buildBottomIconButton(
                          icon: Icons.queue_music_rounded,
                          isSelected: _activeSheetIndex == 2,
                          ambientColor: player.ambientColor,
                          onTap: () => setState(() => _activeSheetIndex = _activeSheetIndex == 2 ? 0 : 2),
                        ),
                        const SizedBox(width: 32),
                        _buildBottomIconButton(
                          icon: Icons.share_rounded,
                          isSelected: false,
                          ambientColor: player.ambientColor,
                          onTap: () => Share.share('Ascolta "${track.title}" di ${track.artistName} su Preluded!\n${AppConfig.getShareUrl(track.id)}'),
                        ),
                      ],
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
    double maxSeconds,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final screenWidth = constraints.maxWidth;
        // Adaptive sizing based on available viewport height
        final isCompact = availableHeight < 560;
        final maxArt = (screenWidth * 0.82).clamp(180.0, 335.0);
        final artSize = (availableHeight * (isCompact ? 0.38 : 0.44)).clamp(180.0, maxArt);

        // Dynamically distribute vertical spacing across the available lower space
        final extraSpace = (availableHeight - (artSize + 52 + 58 + 72)).clamp(20.0, 220.0);
        final spacingTop = (extraSpace * 0.08).clamp(4.0, 16.0);
        final spacingArtToTitle = (extraSpace * 0.28).clamp(14.0, 36.0);
        final spacingTitleToSlider = (extraSpace * 0.24).clamp(12.0, 32.0);
        final spacingSliderToControls = (extraSpace * 0.28).clamp(14.0, 38.0);
        final spacingBottom = (extraSpace * 0.12).clamp(8.0, 24.0);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: spacingTop),

              // 1. Large Squircle 32px Artwork with Dynamic Glow
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
                    width: artSize,
                    height: artSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(isCompact ? 24 : 30),
                      boxShadow: [
                        BoxShadow(
                          color: player.ambientColor.withOpacity(0.40),
                          blurRadius: isCompact ? 24 : 36,
                          offset: const Offset(0, 14),
                          spreadRadius: -4,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.55),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isCompact ? 24 : 30),
                      child: CachedNetworkImage(
                        imageUrl: track.coverUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 600,
                        memCacheHeight: 600,
                        placeholder: (c, u) => Container(color: AppTheme.surfaceContainerLowest),
                        errorWidget: (c, u, e) => Container(
                          color: AppTheme.surfaceContainerLowest,
                          child: const Icon(Icons.music_note_rounded, color: AppTheme.textSecondary, size: 54),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: spacingArtToTitle),

              // 2. Track Title, Artist & Like Button
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
                          style: AppTheme.syne(
                            color: Colors.white,
                            fontSize: isCompact ? 17 : 19.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          track.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.inter(
                            color: Colors.white.withOpacity(0.70),
                            fontSize: isCompact ? 13 : 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isLiked ? AppTheme.primaryAccent.withOpacity(0.15) : Colors.white.withOpacity(0.06),
                    ),
                    child: IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isLiked ? AppTheme.primaryAccent : Colors.white.withOpacity(0.75),
                        size: isCompact ? 24 : 26,
                      ),
                      onPressed: () => context.read<LibraryState>().toggleLike(track),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacingTitleToSlider),


              // 4. Material You Scrubber Slider
              ValueListenableBuilder<Duration>(
                valueListenable: player.positionNotifier,
                builder: (context, pos, _) {
                  final curSec = pos.inSeconds.toDouble();
                  final rem = Duration(seconds: (maxSeconds - curSec).clamp(0, 999999).toInt());
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4.5,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6, elevation: 3),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: player.ambientColor,
                          inactiveTrackColor: Colors.white.withOpacity(0.15),
                          thumbColor: player.ambientColor,
                        ),
                        child: Slider(
                          value: curSec.clamp(0.0, maxSeconds > 0 ? maxSeconds : 1.0),
                          max: maxSeconds > 0 ? maxSeconds : 1.0,
                          onChanged: (val) => player.seek(Duration(seconds: val.toInt())),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(pos),
                              style: AppTheme.inter(color: Colors.white.withOpacity(0.55), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '-${_formatDuration(rem)}',
                              style: AppTheme.inter(color: Colors.white.withOpacity(0.55), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: spacingSliderToControls),

              // 5. Main Controls Row (Material 3 Expressive)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Shuffle
                  IconButton(
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: player.isShuffle ? AppTheme.primaryAccent : Colors.white.withOpacity(0.6),
                      size: isCompact ? 22 : 24,
                    ),
                    onPressed: player.toggleShuffle,
                  ),

                  // Previous
                  IconButton(
                    icon: Icon(Icons.skip_previous_rounded, color: Colors.white, size: isCompact ? 36 : 42),
                    onPressed: player.previousTrack,
                  ),

                  // Play / Pause Large FAB
                  GestureDetector(
                    onTap: player.togglePlay,
                    child: Container(
                      width: isCompact ? 64 : 72,
                      height: isCompact ? 64 : 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryAccent,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryAccent.withOpacity(0.45),
                            blurRadius: 18,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: player.isBuffering
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              ),
                            )
                          : Icon(
                              player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: isCompact ? 36 : 40,
                            ),
                    ),
                  ),

                  // Next
                  IconButton(
                    icon: Icon(Icons.skip_next_rounded, color: Colors.white, size: isCompact ? 36 : 42),
                    onPressed: player.nextTrack,
                  ),

                  // Repeat
                  IconButton(
                    icon: Icon(
                      player.loopMode == LoopMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: player.loopMode != LoopMode.off ? AppTheme.primaryAccent : Colors.white.withOpacity(0.6),
                      size: isCompact ? 22 : 24,
                    ),
                    onPressed: player.cycleRepeat,
                  ),
                ],
              ),
              SizedBox(height: spacingBottom),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomIconButton({
    required IconData icon,
    required bool isSelected,
    required Color ambientColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected
                ? ambientColor.withOpacity(0.35)
                : Colors.white.withOpacity(0.08),
            border: Border.all(
              color: isSelected ? ambientColor : Colors.white.withOpacity(0.12),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: ambientColor.withOpacity(0.40),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 22,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.75),
            ),
          ),
        ),
      ),
    );
  }

  void _showTrackOptions(BuildContext context, dynamic track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
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
  }
}
