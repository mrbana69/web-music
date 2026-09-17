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
  String? _lastYtmCookie;
  bool? _lastIsGoogleLoggedIn;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();
    final library = context.read<LibraryState>();
    library.repairHistoryArtists(api);
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buongiorno';
    if (hour < 18) return 'Buon pomeriggio';
    return 'Buonasera';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerState>();
    final library = context.watch<LibraryState>();
    final userName = library.googleUser?.name.split(' ').first ?? '';

    // Auto-reload data when user logs in or updates session cookie
    if (_lastYtmCookie != library.ytmCookie || _lastIsGoogleLoggedIn != library.isGoogleLoggedIn) {
      _lastYtmCookie = library.ytmCookie;
      _lastIsGoogleLoggedIn = library.isGoogleLoggedIn;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadData();
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        color: AppTheme.primaryAccent,
        backgroundColor: AppTheme.surfaceContainerHigh,
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Material 3 Header with Greeting & Avatar
            SliverAppBar(
              floating: true,
              pinned: false,
              backgroundColor: AppTheme.background.withOpacity(0.9),
              toolbarHeight: 64,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName.isNotEmpty ? '${_getGreeting()}, $userName' : _getGreeting(),
                    style: AppTheme.syne(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    'La tua musica su misura',
                    style: AppTheme.inter(color: AppTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              actions: [
                if (library.isGoogleLoggedIn && (library.googleUser?.avatarUrl.isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.surfaceContainerHigh,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        library.googleUser!.avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: AppTheme.primaryAccent, size: 20),
                      ),
                    ),
                  )
                else
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
              // 3. Scelte Rapide (Quick Picks) Carousel
              if (_quickPicks.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Scelte rapide',
                    subtitle: 'Basate sui tuoi ascolti',
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 215,
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

              // 4. Di nuovo all'ascolto (History)
              if (library.history.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SectionHeader(
                    title: "Di nuovo all'ascolto",
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

              // 5. Dynamic YouTube Music Shelves (filtering out duplicate Scelte rapide)
              for (final entry in _sections.entries) ...[
                if (!entry.key.toLowerCase().contains('scelt') &&
                    !entry.key.toLowerCase().contains('quick') &&
                    !entry.key.toLowerCase().contains('picks')) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: entry.key,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 215,
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
              ],

              // Bottom padding for miniplayer & navbar
              const SliverToBoxAdapter(child: SizedBox(height: 180)),
            ],
          ],
        ),
      ),
    );
  }
}
