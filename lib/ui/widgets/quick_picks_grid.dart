import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/track.dart';
import '../../providers/player_state.dart';
import '../../providers/library_state.dart';
import '../theme/app_theme.dart';

class QuickPicksGrid extends StatefulWidget {
  final List<Track> tracks;
  final VoidCallback? onPlayAll;

  const QuickPicksGrid({
    super.key,
    required this.tracks,
    this.onPlayAll,
  });

  @override
  State<QuickPicksGrid> createState() => _QuickPicksGridState();
}

class _QuickPicksGridState extends State<QuickPicksGrid> {
  final ScrollController _scrollCtrl = ScrollController();

  void _scroll(bool forward) {
    if (!_scrollCtrl.hasClients) return;
    final current = _scrollCtrl.offset;
    const delta = 380.0;
    final target = forward ? current + delta : current - delta;
    _scrollCtrl.animateTo(
      target.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tracks.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 750;
    final player = context.watch<PlayerState>();
    final library = context.watch<LibraryState>();

    final totalTracks = widget.tracks.length;
    final columnCount = (totalTracks / 4).ceil();
    final columnWidth = isDesktop ? 360.0 : (screenWidth * 0.86).clamp(280.0, 360.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with "Scelte rapide", "Riproduci tutti" and Navigation Arrows
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Scelte rapide',
                style: AppTheme.syne(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // "Riproduci tutti" Pill Button
                  InkWell(
                    onTap: () {
                      if (widget.onPlayAll != null) {
                        widget.onPlayAll!();
                      } else if (widget.tracks.isNotEmpty) {
                        player.playTrack(widget.tracks.first, newQueue: widget.tracks, index: 0);
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerHigh.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Riproduci tutti',
                            style: AppTheme.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Carousel navigation arrows
                  if (isDesktop) ...[
                    const SizedBox(width: 10),
                    _buildArrowButton(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => _scroll(false),
                    ),
                    const SizedBox(width: 6),
                    _buildArrowButton(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => _scroll(true),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // 4-Row Column Grid Horizontal Carousel
        SizedBox(
          height: 272,
          child: ListView.builder(
            controller: _scrollCtrl,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: columnCount,
            itemBuilder: (context, colIdx) {
              final start = colIdx * 4;
              final end = (start + 4).clamp(0, totalTracks);
              final colTracks = widget.tracks.sublist(start, end);

              return Container(
                width: columnWidth,
                margin: const EdgeInsets.only(right: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(colTracks.length, (rowIdx) {
                    final overallIdx = start + rowIdx;
                    final track = colTracks[rowIdx];
                    final isCurrent = player.currentTrack?.id == track.id ||
                        (track.videoId.isNotEmpty && player.currentTrack?.videoId == track.videoId);
                    final isPlaying = isCurrent && player.isPlaying;
                    final isLiked = library.isLiked(track.id);

                    return _buildTrackRow(
                      context: context,
                      track: track,
                      overallIdx: overallIdx,
                      isCurrent: isCurrent,
                      isPlaying: isPlaying,
                      isLiked: isLiked,
                      player: player,
                      library: library,
                    );
                  }),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArrowButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.surfaceContainerHigh.withOpacity(0.55),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }

  Widget _buildTrackRow({
    required BuildContext context,
    required Track track,
    required int overallIdx,
    required bool isCurrent,
    required bool isPlaying,
    required bool isLiked,
    required PlayerState player,
    required LibraryState library,
  }) {
    return Container(
      height: 62,
      margin: const EdgeInsets.symmetric(vertical: 2.5),
      decoration: BoxDecoration(
        color: isCurrent ? AppTheme.surfaceContainerHigh.withOpacity(0.7) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            if (isCurrent) {
              player.togglePlay();
            } else {
              player.playTrack(track, newQueue: widget.tracks, index: overallIdx);
            }
          },
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.white.withOpacity(0.06),
          splashColor: AppTheme.primaryAccent.withOpacity(0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                // 48x48 Rounded Squircle Artwork
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: AppTheme.surfaceContainerHighest,
                        child: CachedNetworkImage(
                          imageUrl: track.effectiveCoverUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 120,
                          memCacheHeight: 120,
                          placeholder: (_, __) => Container(color: AppTheme.surfaceContainerHighest),
                          errorWidget: (_, __, ___) {
                            final vId = track.effectiveVideoId;
                            if (vId.isNotEmpty) {
                              return Image.network(
                                'https://i.ytimg.com/vi/$vId/hqdefault.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.music_note_rounded,
                                  color: AppTheme.textSecondary,
                                  size: 20,
                                ),
                              );
                            }
                            return const Icon(
                              Icons.music_note_rounded,
                              color: AppTheme.textSecondary,
                              size: 20,
                            );
                          },
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isPlaying ? Icons.equalizer_rounded : Icons.play_arrow_rounded,
                          color: AppTheme.primaryAccent,
                          size: 24,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.syne(
                          fontSize: 13.5,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                          color: isCurrent ? AppTheme.primaryAccent : Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${track.artistName}${track.albumName.isNotEmpty ? " • ${track.albumName}" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                // Like Button
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isLiked ? const Color(0xFFFA2D48) : Colors.white30,
                    size: 18,
                  ),
                  splashRadius: 18,
                  tooltip: isLiked ? 'Rimuovi dai Preferiti' : 'Aggiungi ai Preferiti',
                  onPressed: () => library.toggleLike(track),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
