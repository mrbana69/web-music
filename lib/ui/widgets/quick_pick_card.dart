import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/track.dart';
import '../theme/app_theme.dart';

class QuickPickCard extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;

  const QuickPickCard({
    super.key,
    required this.track,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      margin: const EdgeInsets.only(right: 14),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Artwork with Floating Play Button
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CachedNetworkImage(
                        imageUrl: track.effectiveCoverUrl,
                        width: 148,
                        height: 148,
                        fit: BoxFit.cover,
                        memCacheWidth: 280,
                        memCacheHeight: 280,
                        placeholder: (c, u) => Container(
                          color: AppTheme.surfaceContainerHighest,
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryAccent,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (c, u, e) {
                          final vId = track.effectiveVideoId;
                          if (vId.isNotEmpty) {
                            return Image.network(
                              'https://i.ytimg.com/vi/$vId/hqdefault.jpg',
                              width: 148,
                              height: 148,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 148,
                                height: 148,
                                color: AppTheme.surfaceContainerHighest,
                                child: const Icon(Icons.music_note_rounded, color: AppTheme.textSecondary, size: 36),
                              ),
                            );
                          }
                          return Container(
                            width: 148,
                            height: 148,
                            color: AppTheme.surfaceContainerHighest,
                            child: const Icon(Icons.music_note_rounded, color: AppTheme.textSecondary, size: 36),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryAccent.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title (Syne)
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.syne(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),

              // Artist (Inter)
              Text(
                track.artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

