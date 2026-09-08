import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';

class LyricsView extends StatefulWidget {
  const LyricsView({super.key});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  bool _showTranslation = false;
  int _lastActiveIndex = -1;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final lyrics = player.lyrics;
    final currentMs = player.position.inMilliseconds;

    if (player.isLoadingLyrics) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryAccent),
      );
    }

    if (lyrics == null || (lyrics.plainText.isEmpty && lyrics.syncedLines.isEmpty)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lyrics_outlined, size: 54, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            const Text(
              'Testi non disponibili per questo brano',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.surfaceElevated,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
              label: const Text('Riprova', style: TextStyle(color: Colors.white)),
              onPressed: () => player.fetchLyricsForCurrentTrack(),
            ),
          ],
        ),
      );
    }

    // If synced karaoke lyrics are available
    if (lyrics.isSynced) {
      final activeIndex = lyrics.findActiveIndex(currentMs);

      // Auto-scroll to active line
      if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
        _lastActiveIndex = activeIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final targetOffset = (activeIndex * 55.0) - 150.0;
            _scrollController.animateTo(
              targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }

      return Column(
        children: [
          // Translation toggle if available
          if (lyrics.translation != null && lyrics.translation!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ChoiceChip(
                    label: const Text('Traduzione'),
                    selected: _showTranslation,
                    onSelected: (val) => setState(() => _showTranslation = val),
                    selectedColor: AppTheme.primaryAccent,
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              itemCount: lyrics.syncedLines.length,
              itemBuilder: (context, i) {
                final line = lyrics.syncedLines[i];
                final isActive = i == activeIndex;
                final isPassed = i < activeIndex;

                return InkWell(
                  onTap: () {
                    player.seek(Duration(milliseconds: line.timestampMs));
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    child: Text(
                      line.text,
                      style: TextStyle(
                        color: isActive
                            ? Colors.white
                            : (isPassed ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.2)),
                        fontSize: isActive ? 24 : 20,
                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                        letterSpacing: -0.3,
                        shadows: isActive
                            ? [
                                BoxShadow(
                                  color: player.ambientColor.withOpacity(0.6),
                                  blurRadius: 18,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    // Plain lyrics view
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Text(
        lyrics.plainText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          height: 1.8,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
