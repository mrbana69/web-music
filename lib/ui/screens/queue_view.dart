import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/track.dart';
import '../../providers/player_state.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';

class QueueView extends StatelessWidget {
  const QueueView({super.key});

  @override
  Widget build(BuildContext context) {
    final queue = context.select<PlayerState, List<Track>>((p) => p.queue);
    final currentIndex = context.select<PlayerState, int>((p) => p.currentIndex);
    final player = context.read<PlayerState>();

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coda di riproduzione',
                    style: AppTheme.syne(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${queue.length} brani in totale',
                    style: AppTheme.inter(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              if (queue.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_all_rounded, color: AppTheme.textSecondary),
                  tooltip: 'Svuota coda',
                  onPressed: () {
                    player.clearQueue();
                  },
                ),
            ],
          ),
        ),

        // Reorderable Queue List
        Expanded(
          child: queue.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: AppTheme.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.queue_music_rounded, size: 48, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nessun brano in coda',
                        style: AppTheme.inter(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 40),
                  itemCount: queue.length,
                  onReorder: player.reorderQueue,
                  itemBuilder: (context, i) {
                    final track = queue[i];
                    final isCurrent = i == currentIndex;

                    return Dismissible(
                      key: ValueKey('queue_${track.id}_$i'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
                      ),
                      onDismissed: (_) => player.removeFromQueue(i),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isCurrent ? AppTheme.surfaceContainerHigh.withOpacity(0.6) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: isCurrent
                              ? Border.all(color: AppTheme.primaryAccent.withOpacity(0.35))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TrackTile(
                                track: track,
                                index: i,
                                showIndex: true,
                                onTap: () => player.playTrack(track, index: i),
                              ),
                            ),
                            ReorderableDragStartListener(
                              index: i,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                child: Icon(Icons.drag_handle_rounded, color: AppTheme.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

