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
                      ? _buildEmptyPrompt()
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

  Widget _buildEmptyPrompt() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surfaceContainerHigh.withOpacity(0.6),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(
                Icons.search_rounded,
                size: 34,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Cerca su Preluded',
              style: AppTheme.syne(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Digita un brano, artista, album o playlist',
              style: AppTheme.inter(
                color: AppTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final hasResults = switch (_selectedFilter) {
      'tracks' => _tracks.isNotEmpty,
      'artists' => _artists.isNotEmpty,
      'albums' => _albums.isNotEmpty,
      'playlists' => _playlists.isNotEmpty,
      _ => _tracks.isNotEmpty || _artists.isNotEmpty || _albums.isNotEmpty || _playlists.isNotEmpty,
    };

    if (!hasResults) {
      return const Center(
        child: Text('Nessun risultato trovato', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 180),
      children: [
        // Dedicated Artists View
        if (_selectedFilter == 'artists') ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              '${_artists.length} ${_artists.length == 1 ? "Artista trovato" : "Artisti trovati"}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ..._artists.map((artist) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.surfaceContainerHighest,
              backgroundImage: artist.picture.isNotEmpty ? NetworkImage(artist.picture) : null,
              child: artist.picture.isEmpty
                  ? const Icon(Icons.person_rounded, color: AppTheme.textSecondary, size: 28)
                  : null,
            ),
            title: Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'Artista',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ArtistScreen(artist: artist)),
              );
            },
          )),
        ],

        // Dedicated Albums View
        if (_selectedFilter == 'albums') ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              '${_albums.length} ${_albums.length == 1 ? "Album trovato" : "Album trovati"}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ..._albums.map((album) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: album.coverUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                memCacheWidth: 104,
                memCacheHeight: 104,
                placeholder: (c, u) => Container(width: 52, height: 52, color: AppTheme.surfaceContainerHighest),
                errorWidget: (c, u, e) => Container(
                  width: 52,
                  height: 52,
                  color: AppTheme.surfaceContainerHighest,
                  child: const Icon(Icons.album_rounded, color: AppTheme.textSecondary),
                ),
              ),
            ),
            title: Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              album.artistName.isNotEmpty ? 'Album • ${album.artistName}' : 'Album',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AlbumScreen(album: album)),
              );
            },
          )),
        ],

        // Dedicated Playlists View
        if (_selectedFilter == 'playlists') ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              '${_playlists.length} ${_playlists.length == 1 ? "Playlist trovata" : "Playlist trovate"}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ..._playlists.map((pl) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: pl.coverUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                memCacheWidth: 104,
                memCacheHeight: 104,
                placeholder: (c, u) => Container(width: 52, height: 52, color: AppTheme.surfaceContainerHighest),
                errorWidget: (c, u, e) => Container(
                  width: 52,
                  height: 52,
                  color: AppTheme.surfaceContainerHighest,
                  child: const Icon(Icons.playlist_play_rounded, color: AppTheme.textSecondary),
                ),
              ),
            ),
            title: Text(
              pl.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              pl.subtitle.isNotEmpty ? pl.subtitle : 'Playlist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
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
          )),
        ],

        // Combined "all" view: Artists Carousel
        if (_selectedFilter == 'all' && _artists.isNotEmpty) ...[
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

        // Combined "all" view: Albums Carousel
        if (_selectedFilter == 'all' && _albums.isNotEmpty) ...[
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

        // Combined "all" view: Playlists Carousel
        if (_selectedFilter == 'all' && _playlists.isNotEmpty) ...[
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

        // Tracks List (for 'all' or 'tracks')
        if (_tracks.isNotEmpty && (_selectedFilter == 'all' || _selectedFilter == 'tracks')) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              _selectedFilter == 'tracks'
                  ? '${_tracks.length} ${_tracks.length == 1 ? "Brano trovato" : "Brani trovati"}'
                  : 'Brani',
              style: const TextStyle(
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

