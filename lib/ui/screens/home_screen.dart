import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/track.dart';
import '../../providers/player_state.dart';
import '../../providers/library_state.dart';
import '../theme/app_theme.dart';
import '../widgets/section_header.dart';
import '../widgets/quick_pick_card.dart';
import '../widgets/track_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Track> _quickPicks = [];
  Map<String, List<Track>> _sections = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();
    try {
      final qp = await api.fetchQuickPicks();
      final sec = await api.fetchHomeSections();
      if (mounted) {
        setState(() {
          _quickPicks = qp;
          _sections = sec;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerState>();
    final library = context.watch<LibraryState>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        color: AppTheme.primaryAccent,
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Bar / Header
            SliverAppBar(
              floating: true,
              backgroundColor: AppTheme.background.withOpacity(0.85),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scopri',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  Text(
                    'La tua musica, senza limiti',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: _loadData,
                ),
              ],
            ),

            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryAccent),
                ),
              )
            else ...[
              // 1. Scelte Rapide (Quick Picks)
              if (_quickPicks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Scelte rapide',
                    subtitle: 'Ascolta i tuoi brani preferiti',
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 205,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _quickPicks.length,
                      itemBuilder: (context, i) {
                        final track = _quickPicks[i];
                        return QuickPickCard(
                          track: track,
                          onTap: () => player.playTrack(track, newQueue: _quickPicks, index: i),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // 2. Di nuovo all'ascolto (History)
              if (library.history.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Di nuovo all'ascolto',
                    subtitle: 'I tuoi ascolti recenti',
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final track = library.history[i];
                      return TrackTile(
                        track: track,
                        queue: library.history,
                        index: i,
                      );
                    },
                    childCount: library.history.length.clamp(0, 6),
                  ),
                ),
              ],

              // 3. Dynamic YouTube Music Home Sections
              for (final entry in _sections.entries) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: entry.key,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 205,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: entry.value.length,
                      itemBuilder: (context, i) {
                        final track = entry.value[i];
                        return QuickPickCard(
                          track: track,
                          onTap: () => player.playTrack(track, newQueue: entry.value, index: i),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // Bottom padding for miniplayer
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ],
        ),
      ),
    );
  }
}
