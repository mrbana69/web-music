import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import '../../models/track.dart';
import '../../models/album.dart';
import '../../models/artist.dart';
import '../../providers/player_state.dart';
import '../../providers/library_state.dart';
import '../../config/app_config.dart';
import '../theme/app_theme.dart';
import 'lyrics_view.dart';
import 'queue_view.dart';
import 'album_screen.dart';
import 'artist_screen.dart';

class FullPlayerScreen extends StatefulWidget {
  final int initialTab;
  const FullPlayerScreen({super.key, this.initialTab = 0});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  late int _activeSheetIndex;

  @override
  void initState() {
    super.initState();
    _activeSheetIndex = widget.initialTab;
  }

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
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 24),
                          tooltip: 'Opzioni brano',
                          color: AppTheme.surfaceContainerHigh,
                          elevation: 12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.white.withOpacity(0.12)),
                          ),
                          offset: const Offset(0, 48),
                          onSelected: (action) => _handleTrackAction(context, action, track),
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'mix',
                              child: Row(
                                children: [
                                  const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryAccent, size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Avvia mix',
                                    style: AppTheme.syne(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'album',
                              child: Row(
                                children: [
                                  Icon(Icons.album_rounded, color: Colors.white.withOpacity(0.85), size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Visualizza album',
                                    style: AppTheme.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'artist',
                              child: Row(
                                children: [
                                  Icon(Icons.person_rounded, color: Colors.white.withOpacity(0.85), size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Visualizza artista',
                                    style: AppTheme.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'playlist',
                              child: Row(
                                children: [
                                  Icon(Icons.playlist_add_rounded, color: Colors.white.withOpacity(0.85), size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Aggiungi a playlist',
                                    style: AppTheme.inter(fontSize: 13.5, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.85)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // --- Body: Player, Lyrics, or Queue ---
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: _activeSheetIndex == 1 ? double.infinity : (_activeSheetIndex == 2 ? 680 : 1100),
                        ),
                        child: _activeSheetIndex == 1
                            ? const LyricsView()
                            : (_activeSheetIndex == 2
                                ? const QueueView()
                                : _buildPlayerBody(context, player, track, isLiked, maxSeconds)),
                      ),
                    ),
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
        final isWide = screenWidth >= 620;

        // Desktop / Tablet Landscape Side-by-Side Centered Layout
        if (isWide) {
          final sideArtSize = (screenWidth * 0.38).clamp(240.0, 420.0).clamp(200.0, availableHeight * 0.72);
          return Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left Column: Centered Song Artwork
                    Expanded(
                      flex: 5,
                      child: Center(
                        child: _buildArtwork(track, player, sideArtSize, false),
                      ),
                    ),
                    const SizedBox(width: 48),
                    // Right Column: Centered Player Controls
                    Expanded(
                      flex: 6,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTrackInfo(track, isLiked, false),
                          const SizedBox(height: 28),
                          _buildScrubber(context, player, maxSeconds),
                          const SizedBox(height: 24),
                          _buildPlaybackControls(player, false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Mobile / Narrow Portrait Column Layout
        final isCompact = availableHeight < 560;
        final maxArt = (screenWidth * 0.82).clamp(180.0, 335.0);
        final artSize = (availableHeight * (isCompact ? 0.38 : 0.44)).clamp(180.0, maxArt);

        final extraSpace = (availableHeight - (artSize + 52 + 58 + 72)).clamp(20.0, 220.0);
        final spacingTop = (extraSpace * 0.08).clamp(4.0, 16.0);
        final spacingArtToTitle = (extraSpace * 0.28).clamp(14.0, 36.0);
        final spacingTitleToSlider = (extraSpace * 0.24).clamp(12.0, 32.0);
        final spacingSliderToControls = (extraSpace * 0.28).clamp(14.0, 38.0);
        final spacingBottom = (extraSpace * 0.12).clamp(8.0, 24.0);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: spacingTop),
                  _buildArtwork(track, player, artSize, isCompact),
                  SizedBox(height: spacingArtToTitle),
                  _buildTrackInfo(track, isLiked, isCompact),
                  SizedBox(height: spacingTitleToSlider),
                  _buildScrubber(context, player, maxSeconds),
                  SizedBox(height: spacingSliderToControls),
                  _buildPlaybackControls(player, isCompact),
                  SizedBox(height: spacingBottom),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtwork(dynamic track, PlayerState player, double artSize, bool isCompact) {
    return GestureDetector(
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
            borderRadius: BorderRadius.circular(isCompact ? 24 : 32),
            boxShadow: [
              BoxShadow(
                color: player.ambientColor.withOpacity(0.42),
                blurRadius: isCompact ? 24 : 38,
                offset: const Offset(0, 14),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isCompact ? 24 : 32),
            child: CachedNetworkImage(
              imageUrl: track.effectiveCoverUrl,
              fit: BoxFit.cover,
              memCacheWidth: 600,
              memCacheHeight: 600,
              placeholder: (c, u) => Container(color: AppTheme.surfaceContainerLowest),
              errorWidget: (c, u, e) {
                final vId = track.effectiveVideoId;
                if (vId.isNotEmpty) {
                  return Image.network(
                    'https://i.ytimg.com/vi/$vId/hqdefault.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.surfaceContainerLowest,
                      child: const Icon(Icons.music_note_rounded, color: AppTheme.textSecondary, size: 54),
                    ),
                  );
                }
                return Container(
                  color: AppTheme.surfaceContainerLowest,
                  child: const Icon(Icons.music_note_rounded, color: AppTheme.textSecondary, size: 54),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackInfo(dynamic track, bool isLiked, bool isCompact) {
    return Row(
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
                  fontSize: isCompact ? 17 : 21,
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
                  fontSize: isCompact ? 13 : 15,
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
    );
  }

  Widget _buildScrubber(BuildContext context, PlayerState player, double maxSeconds) {
    return ValueListenableBuilder<Duration>(
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
    );
  }

  Widget _buildPlaybackControls(PlayerState player, bool isCompact) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Shuffle
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            color: player.isShuffle ? AppTheme.primaryAccent : Colors.white.withOpacity(0.6),
            size: isCompact ? 22 : 24,
          ),
          mouseCursor: SystemMouseCursors.click,
          tooltip: 'Riproduzione casuale',
          onPressed: player.toggleShuffle,
        ),

        // Previous
        IconButton(
          icon: Icon(Icons.skip_previous_rounded, color: Colors.white, size: isCompact ? 36 : 42),
          mouseCursor: SystemMouseCursors.click,
          tooltip: 'Brano precedente',
          onPressed: player.previousTrack,
        ),

        // Play / Pause Large FAB
        Material(
          color: AppTheme.primaryAccent,
          shape: const CircleBorder(),
          elevation: 6,
          shadowColor: AppTheme.primaryAccent.withOpacity(0.45),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            mouseCursor: SystemMouseCursors.click,
            onTap: player.togglePlay,
            splashColor: Colors.white.withOpacity(0.25),
            highlightColor: Colors.white.withOpacity(0.12),
            child: SizedBox(
              width: isCompact ? 64 : 72,
              height: isCompact ? 64 : 72,
              child: player.isBuffering
                  ? const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
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
        ),

        // Next
        IconButton(
          icon: Icon(Icons.skip_next_rounded, color: Colors.white, size: isCompact ? 36 : 42),
          mouseCursor: SystemMouseCursors.click,
          tooltip: 'Brano successivo',
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
          mouseCursor: SystemMouseCursors.click,
          tooltip: 'Ripetizione',
          onPressed: player.cycleRepeat,
        ),
      ],
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

  Future<void> _handleTrackAction(BuildContext context, String action, Track track) async {
    switch (action) {
      case 'mix':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.surfaceContainerHighest,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Caricamento mix per "${track.title}"...',
                    style: AppTheme.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        final player = context.read<PlayerState>();
        final count = await player.startMix(track);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (count > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.primaryContainer,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Mix avviato: $count brani correlati in coda',
                      style: AppTheme.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.surfaceContainerHighest,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(
                'Nessun brano correlato trovato al momento',
                style: AppTheme.inter(color: Colors.white, fontSize: 13),
              ),
            ),
          );
        }
        break;

      case 'album':
        final albumTitle = track.albumName.isNotEmpty ? track.albumName : track.title;
        final album = Album(
          id: track.albumId,
          title: albumTitle,
          artistName: track.artistName,
          artistId: track.artistId,
          coverUrl: track.coverUrl,
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AlbumScreen(album: album),
          ),
        );
        break;

      case 'artist':
        final artist = Artist(
          id: track.artistId.isNotEmpty ? track.artistId : track.artistName,
          name: track.artistName,
          picture: track.coverUrl,
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArtistScreen(artist: artist),
          ),
        );
        break;

      case 'playlist':
        _showAddToPlaylistDialog(context, track);
        break;
    }
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Aggiungi a Playlist',
                    style: AppTheme.syne(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
                const SizedBox(height: 14),
                if (library.playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                    child: Center(
                      child: Text(
                        'Nessuna playlist creata. Creane una dalla Libreria!',
                        style: AppTheme.inter(color: AppTheme.textSecondary),
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
                          title: Text(pl.title, style: AppTheme.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                          subtitle: Text('${pl.tracks.length} brani', style: AppTheme.inter(color: AppTheme.textSecondary, fontSize: 12)),
                          onTap: () {
                            library.addTrackToPlaylist(pl.id, track);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Aggiunto a "${pl.title}"'),
                                backgroundColor: AppTheme.surfaceContainerHighest,
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

