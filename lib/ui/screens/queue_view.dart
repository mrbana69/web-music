import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_state.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';

class QueueView extends StatelessWidget {
  const QueueView({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final queue = player.queue;
    final currentIndex = player.currentIndex;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Coda di riproduzione (${queue.length})',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Trascina per riordinare',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),

        // Reorderable Queue List
        Expanded(
          child: queue.isEmpty
              ? const Center(
                  child: Text('Nessun brano in coda', style: TextStyle(color: AppTheme.textSecondary)),
                )
              : ReorderableListView.builder(
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
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red.withOpacity(0.8),
                        child: const Icon(Icons.delete_outline, color: Colors.white),
                      ),
                      onDismissed: (_) => player.removeFromQueue(i),
                      child: Container(
                        color: isCurrent ? AppTheme.primaryAccent.withOpacity(0.1) : Colors.transparent,
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
