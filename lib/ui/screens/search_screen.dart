import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../models/track.dart';
import '../../models/artist.dart';
import '../../models/album.dart';
import '../../models/playlist.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';
import 'artist_screen.dart';
import 'album_screen.dart';
import 'playlist_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _selectedFilter = 'all';
  bool _isLoading = false;

  List<Track> _tracks = [];
  List<Artist> _artists = [];
  List<Album> _albums = [];
  List<Playlist> _playlists = [];

  final List<String> _trendingSearches = [
    'Sfera Ebbasta',
    'Geolier',
    'Annalisa',
    'Lazza',
    'Travis Scott',
    'The Weeknd',
    'Tedua',
    'Rose Villain',
    'Marracash',
    'Capo Plaza',
  ];

  final List<Map<String, dynamic>> _genreCards = [
    {'title': 'Trap Italia', 'color': Color(0xFFFA2D48), 'icon': Icons.whatshot_rounded},
    {'title': 'Pop Hits', 'color': Color(0xFFFF6B6B), 'icon': Icons.star_rounded},
    {'title': 'Hip Hop & Rap', 'color': Color(0xFF7928CA), 'icon': Icons.mic_rounded},
    {'title': 'Dance & EDM', 'color': Color(0xFF0070F3), 'icon': Icons.graphic_eq_rounded},
    {'title': 'Chill & Relax', 'color': Color(0xFF10B981), 'icon': Icons.spa_rounded},
    {'title': 'Rock & Indie', 'color': Color(0xFFF59E0B), 'icon': Icons.album_rounded},
  ];

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _tracks = [];
        _artists = [];
        _albums = [];
        _playlists = [];
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();
    try {
      final res = await api.search(query, filter: _selectedFilter);
      if (mounted) {
        setState(() {
          _tracks = (res['tracks'] as List<Track>?) ?? [];
          _artists = (res['artists'] as List<Artist>?) ?? [];
          _albums = (res['albums'] as List<Album>?) ?? [];
          _playlists = (res['playlists'] as List<Playlist>?) ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search Header & Material 3 SearchBar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cerca',
                    style: AppTheme.syne(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // M3 Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: AppTheme.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      cursorColor: AppTheme.primaryAccent,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Cosa vuoi ascoltare?',
                        hintStyle: AppTheme.inter(color: AppTheme.textMuted, fontSize: 15),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Icon(Icons.search_rounded, color: AppTheme.primaryAccent, size: 24),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip('Tutto', 'all'),
                        _buildFilterChip('Brani', 'tracks'),
                        _buildFilterChip('Artisti', 'artists'),
                        _buildFilterChip('Album', 'albums'),
                        _buildFilterChip('Playlist', 'playlists'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent))
                  : _searchCtrl.text.isEmpty
                      ? _buildSearchDiscovery()
                      : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        showCheckmark: false,
        onSelected: (val) {
          setState(() => _selectedFilter = value);
          if (_searchCtrl.text.isNotEmpty) {
            _performSearch(_searchCtrl.text);
          }
        },
        backgroundColor: AppTheme.surfaceContainerLow,
        selectedColor: AppTheme.primaryAccent,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryAccent : Colors.white.withOpacity(0.08),
        ),
      ),
    );
  }

  Widget _buildSearchDiscovery() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🔥 Di tendenza',
            style: AppTheme.syne(
              color: AppTheme.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _trendingSearches.map((s) {
              return ActionChip(
                label: Text(s),
                backgroundColor: AppTheme.surfaceContainerHigh,
                labelStyle: AppTheme.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: BorderSide(color: Colors.white.withOpacity(0.06)),
                onPressed: () {
                  _searchCtrl.text = s;
                  _onSearchChanged(s);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          Text(
            'Esplora per Genere',
            style: AppTheme.syne(
              color: AppTheme.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _genreCards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            itemBuilder: (context, i) {
              final card = _genreCards[i];
              final color = card['color'] as Color;
              return Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () {
                    _searchCtrl.text = card['title'] as String;
                    _onSearchChanged(_searchCtrl.text);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.85), color.withOpacity(0.45)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            card['title'] as String,
                            style: AppTheme.syne(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(card['icon'] as IconData, color: Colors.white.withOpacity(0.9), size: 28),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_tracks.isEmpty && _artists.isEmpty && _albums.isEmpty && _playlists.isEmpty) {
      return const Center(
        child: Text('Nessun risultato trovato', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 180),
      children: [
        // Artists Carousel if any
        if (_artists.isNotEmpty && (_selectedFilter == 'all' || _selectedFilter == 'artists')) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'Artisti',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _artists.length,
              itemBuilder: (context, i) {
                final artist = _artists[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ArtistScreen(artist: artist)),
                      );
                    },
                    borderRadius: BorderRadius.circular(50),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppTheme.surfaceContainerHighest,
                          backgroundImage: artist.picture.isNotEmpty ? NetworkImage(artist.picture) : null,
                          child: artist.picture.isEmpty
                              ? const Icon(Icons.person_rounded, color: AppTheme.textSecondary, size: 32)
                              : null,
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 80,
                          child: Text(
                            artist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
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

        // Albums Carousel if any
        if (_albums.isNotEmpty && (_selectedFilter == 'all' || _selectedFilter == 'albums')) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'Album',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 165,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _albums.length,
              itemBuilder: (context, i) {
                final album = _albums[i];
                return Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AlbumScreen(album: album)),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: album.coverUrl,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            memCacheWidth: 240,
                            memCacheHeight: 240,
                            placeholder: (c, u) => Container(color: AppTheme.surfaceContainerHighest),
                            errorWidget: (c, u, e) => Container(
                              width: 120,
                              height: 120,
                              color: AppTheme.surfaceContainerHighest,
                              child: const Icon(Icons.album_rounded, color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          album.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
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

        // Playlists Carousel if any
        if (_playlists.isNotEmpty && (_selectedFilter == 'all' || _selectedFilter == 'playlists')) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'Playlist',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 165,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _playlists.length,
              itemBuilder: (context, i) {
                final pl = _playlists[i];
                return Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlaylistScreen(
                            title: pl.title,
                            subtitle: pl.subtitle,
                            tracks: const [],
                            playlistId: pl.id,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: pl.coverUrl,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            memCacheWidth: 240,
                            memCacheHeight: 240,
                            placeholder: (c, u) => Container(color: AppTheme.surfaceContainerHighest),
                            errorWidget: (c, u, e) => Container(
                              width: 120,
                              height: 120,
                              color: AppTheme.surfaceContainerHighest,
                              child: const Icon(Icons.playlist_play_rounded, color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          pl.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
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

        // Tracks List
        if (_tracks.isNotEmpty && (_selectedFilter == 'all' || _selectedFilter == 'tracks')) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'Brani',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._tracks.asMap().entries.map((entry) {
            return TrackTile(
              track: entry.value,
              queue: _tracks,
              index: entry.key,
            );
          }),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}

