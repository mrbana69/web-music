import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/library_state.dart';
import '../../config/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import 'playlist_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'La tua Libreria',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryAccent, size: 28),
                      onPressed: () => _showCreatePlaylistDialog(context),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: GlassContainer(
                  borderRadius: 18,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaylistScreen(
                          title: 'Brani Preferiti',
                          subtitle: '${library.likedTracks.length} brani preferiti',
                          tracks: library.likedTracks,
                          isLikedSongs: true,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFA2D48), Color(0xFF7928CA)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(Icons.favorite, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Brani Preferiti',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${library.likedTracks.length} brani',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Playlist create',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    TextButton.icon(
                      onPressed: () => _showCreatePlaylistDialog(context),
                      icon: const Icon(Icons.add, color: AppTheme.primaryAccent, size: 18),
                      label: const Text('Crea', style: TextStyle(color: AppTheme.primaryAccent)),
                    ),
                  ],
                ),
              ),
            ),
            if (library.playlists.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    'Nessuna playlist personalizzata. Creane una con il pulsante "+"',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final pl = library.playlists[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: GlassContainer(
                        borderRadius: 14,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlaylistScreen(
                                title: pl.title,
                                subtitle: pl.subtitle,
                                tracks: pl.tracks,
                                playlistId: pl.id,
                              ),
                            ),
                          );
                        },
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.queue_music, color: AppTheme.primaryAccent),
                          ),
                          title: Text(pl.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          subtitle: Text('${pl.tracks.length} brani', style: const TextStyle(color: AppTheme.textSecondary)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.textMuted, size: 20),
                            onPressed: () => library.deletePlaylist(pl.id),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: library.playlists.length,
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Account & Sessioni',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    GlassContainer(
                      borderRadius: 14,
                      onTap: () => _showYtmCookieDialog(context),
                      child: ListTile(
                        leading: const Icon(Icons.key_rounded, color: AppTheme.primaryAccent),
                        title: const Text('Sessione YouTube Music', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          library.ytmCookie != null ? 'Sessione attiva' : 'Non configurata (Tocca per inserire)',
                          style: TextStyle(color: library.ytmCookie != null ? Colors.greenAccent : AppTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassContainer(
                      borderRadius: 14,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryAccent.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.primaryAccent.withOpacity(0.4)),
                                ),
                                child: Text(
                                  AppConfig.appCommit,
                                  style: const TextStyle(color: AppTheme.primaryAccent, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text('Versione v${AppConfig.appVersion} iOS Native', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Build: ${AppConfig.buildTime}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.surfaceElevated,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            icon: const Icon(Icons.cleaning_services_rounded, color: Colors.white, size: 16),
                            label: const Text('Svuota Cache & Reset', style: TextStyle(color: Colors.white, fontSize: 12)),
                            onPressed: () {
                              library.clearAllCache();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Cache locale svuotata con successo')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nuova Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Nome playlist', hintStyle: TextStyle(color: AppTheme.textMuted)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<LibraryState>().createPlaylist(ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Crea', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showYtmCookieDialog(BuildContext context) {
    final library = context.read<LibraryState>();
    final ctrl = TextEditingController(text: library.ytmCookie ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sessione YouTube Music', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Incolla il valore del cookie SAPISID per sbloccare l'estrazione audio diretta e le tue Scelte Rapide:",
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Incolla qui SAPISID...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          if (library.ytmCookie != null)
            TextButton(
              onPressed: () {
                library.saveYtmCookie(null);
                Navigator.pop(ctx);
              },
              child: const Text('Rimuovi', style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
            onPressed: () {
              library.saveYtmCookie(ctrl.text.trim().isNotEmpty ? ctrl.text.trim() : null);
              Navigator.pop(ctx);
            },
            child: const Text('Salva', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
