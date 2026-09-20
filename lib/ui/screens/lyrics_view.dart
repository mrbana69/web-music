import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_state.dart';
import '../theme/app_theme.dart';

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

    if (player.isLoadingLyrics) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primaryAccent),
            ),
            const SizedBox(height: 16),
            Text(
              'Caricamento testi karaoke...',
              style: AppTheme.inter(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (lyrics == null || (lyrics.plainText.isEmpty && lyrics.syncedLines.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lyrics_rounded, size: 48, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 18),
              Text(
                'Testi non disponibili',
                style: AppTheme.syne(color: AppTheme.textPrimary, fontSize: 15.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Non siamo riusciti a sincronizzare i testi per questo brano.',
                textAlign: TextAlign.center,
                style: AppTheme.inter(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.surfaceContainerHighest,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Riprova', style: AppTheme.inter(fontWeight: FontWeight.w600)),
                onPressed: () => player.fetchLyricsForCurrentTrack(),
              ),
            ],
          ),
        ),
      );
    }

    // If synced karaoke lyrics are available
    if (lyrics.isSynced) {
      return ValueListenableBuilder<Duration>(
        valueListenable: player.positionNotifier,
        builder: (context, pos, _) {
          final currentMs = pos.inMilliseconds;
          final activeIndex = lyrics.findActiveIndex(currentMs);

          // Auto-scroll to active line
          if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
            _lastActiveIndex = activeIndex;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                final screenH = MediaQuery.of(context).size.height;
                final targetOffset = (activeIndex * 82.0) - (screenH * 0.32);
                _scrollController.animateTo(
                  targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 400),
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
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilterChip(
                        label: const Text('Traduzione'),
                        selected: _showTranslation,
                        onSelected: (val) => setState(() => _showTranslation = val),
                        backgroundColor: AppTheme.surfaceContainerLow,
                        selectedColor: AppTheme.primaryAccent,
                        labelStyle: AppTheme.inter(
                          color: _showTranslation ? Colors.white : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                  itemCount: lyrics.syncedLines.length,
                  itemBuilder: (context, i) {
                    final line = lyrics.syncedLines[i];
                    final isActive = i == activeIndex;
                    final isPassed = i < activeIndex;

                    return InkWell(
                      onTap: () {
                        player.seek(Duration(milliseconds: line.timestampMs));
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: isActive ? player.ambientColor.withOpacity(0.20) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: isActive
                              ? Border.all(color: player.ambientColor.withOpacity(0.35), width: 1)
                              : null,
                        ),
                        child: Text(
                          line.text,
                          style: AppTheme.syne(
                            color: isActive
                                ? Colors.white
                                : (isPassed ? Colors.white.withOpacity(0.52) : Colors.white.withOpacity(0.26)),
                            fontSize: isActive ? 32 : 22,
                            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                            letterSpacing: -0.4,
                            shadows: isActive
                                ? [
                                    Shadow(
                                      color: player.ambientColor.withOpacity(0.65),
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
        },
      );
    }

    // Plain lyrics view
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 44),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Text(
            lyrics.plainText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w600,
              height: 1.85,
              letterSpacing: -0.3,
            ),
          ),
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

